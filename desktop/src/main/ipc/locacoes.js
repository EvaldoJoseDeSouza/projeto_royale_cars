// =====================================================================
//  IPC das locações (retirada, devolução e cancelamento)
// ---------------------------------------------------------------------
//  Aqui o desktop NÃO grava direto nas tabelas. Ele chama as funções do
//  banco, as mesmas que a web e o celular usam:
//
//    registrar_aluguel   → cria o aluguel e marca o carro como Alugado
//    registrar_devolucao → fecha o aluguel, calcula tudo e libera o carro
//    cancelar_aluguel    → cancela e libera o carro
//
//  Por quê? Antes eram dois passos separados: gravar a locação e depois
//  mudar o status do carro. Se a internet caísse entre os dois, ficava
//  um aluguel registrado com o carro "Disponível". A função do banco faz
//  tudo de uma vez: ou dá tudo certo, ou nada é gravado (isso se chama
//  TRANSAÇÃO). E a conta (dias, atraso, total) é feita num lugar só, igual
//  para as 3 plataformas.
// =====================================================================

const { ipcMain, BrowserWindow } = require("electron");
const supabase = require("../supabase");
const { temPermissao } = require("../sessao");
const { traduzirErroBanco } = require("../erros-banco");
const { lerDinheiro } = require("./frota");

// A "visão" vw_locacoes já junta locação + cliente + veículo e calcula
// o atraso de hoje (status_exibicao = "Atrasada", dias_atraso_atual).
const COLUNAS_ATIVAS =
  "id, veiculo_id, cliente_nome, cliente_telefone, marca, modelo, placa, data_retirada, data_prevista, " +
  "valor_diaria, valor_previsto, km_saida, observacoes, status, status_exibicao, dias_atraso_atual";

const COLUNAS_HISTORICO =
  "id, cliente_nome, marca, modelo, placa, data_retirada, data_prevista, data_devolucao, valor_diaria, " +
  "dias_atraso, valor_atraso, taxas_extras, taxas_motivo, valor_total, km_saida, km_retorno, km_rodados, " +
  "observacoes, status, encerrado_por";

const MENSAGENS_DO_BANCO = {
  km_retorno_valido: "A quilometragem de retorno não pode ser menor que a de saída.",
  taxas_com_motivo: "Informe o motivo das taxas extras (ex.: combustível, limpeza, avaria).",
};

const texto = (valor) => String(valor ?? "").trim();
const inteiroOuNulo = (valor) => {
  const numeros = String(valor ?? "").replace(/\D/g, "");
  return numeros ? Number(numeros) : null;
};
const dinheiro = (valor) => Number(valor || 0).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });

// "deps" vem do index.js
function registrarIpcLocacoes(deps) {
  const { mostrarAviso, obterJanelaDashboard, obterJanelaLocacao, obterJanelaDevolucao, obterJanelaCancelamento } = deps;

  // Aluguel mexe na locação E no carro: as duas listas precisam atualizar
  function avisarQueLocacoesMudaram() {
    BrowserWindow.getAllWindows().forEach((janela) => {
      if (janela.isDestroyed()) return;
      janela.webContents.send("locacoes-atualizadas");
      janela.webContents.send("frota-atualizada");
    });
  }

  async function negarSemPermissao(janela, chave) {
    if (temPermissao(chave)) return false;
    await mostrarAviso(janela, {
      tipo: "erro",
      titulo: "Permissão negada",
      mensagem: "Você não tem permissão para fazer isso. Fale com o responsável pela locadora.",
    });
    return true;
  }

  // ---------------------------------------------------------- LISTAR
  ipcMain.handle("buscar-locacoes-ativas", async () => {
    const { data, error } = await supabase
      .from("vw_locacoes")
      .select(COLUNAS_ATIVAS)
      .eq("status", "Em andamento")
      .order("data_prevista", { ascending: true }); // quem vence primeiro aparece primeiro

    if (error) {
      console.error("Erro ao buscar locações em andamento:", error.message);
      return [];
    }
    return data;
  });

  ipcMain.handle("buscar-locacoes-historico", async () => {
    const { data, error } = await supabase
      .from("vw_locacoes")
      .select(COLUNAS_HISTORICO)
      .in("status", ["Finalizada", "Cancelada"])
      .order("finalizado_em", { ascending: false })
      .limit(300);

    if (error) {
      console.error("Erro ao buscar histórico de locações:", error.message);
      return [];
    }
    return data;
  });

  // -------------------------------------------------------- RETIRADA
  ipcMain.handle("registrar-aluguel", async (event, dados) => {
    const janela = obterJanelaLocacao();
    const avisarErro = (mensagem) => mostrarAviso(janela, { tipo: "erro", titulo: "Aluguel não registrado", mensagem });

    if (await negarSemPermissao(janela, "locacoes_gerenciar")) return { sucesso: false };

    if (!dados.cliente_id || !dados.veiculo_id) {
      await avisarErro("Escolha o cliente e o veículo.");
      return { sucesso: false };
    }
    if (!dados.data_retirada || !dados.data_prevista) {
      await avisarErro("Informe a data de retirada e a de devolução prevista.");
      return { sucesso: false };
    }

    // As outras regras (CNH vencida, carro indisponível, datas fora do
    // limite, km menor que a atual) quem confere é a função do banco.
    const { data: idNovo, error } = await supabase.rpc("registrar_aluguel", {
      p_cliente_id: Number(dados.cliente_id),
      p_veiculo_id: Number(dados.veiculo_id),
      p_data_retirada: dados.data_retirada,
      p_data_prevista: dados.data_prevista,
      p_observacoes: texto(dados.observacoes) || null,
      p_km_saida: inteiroOuNulo(dados.km_saida),
    });

    if (error) {
      console.error("Banco recusou o aluguel:", error.code, error.message);
      await avisarErro(traduzirErroBanco(error, MENSAGENS_DO_BANCO));
      return { sucesso: false };
    }

    avisarQueLocacoesMudaram();
    await mostrarAviso(janela, {
      tipo: "sucesso",
      titulo: "Aluguel registrado",
      mensagem: `Aluguel #${idNovo} registrado. O carro agora aparece como Alugado.`,
    });
    return { sucesso: true, id: idNovo };
  });

  // ------------------------------------------------------- DEVOLUÇÃO
  ipcMain.handle("registrar-devolucao", async (event, dados) => {
    const janela = obterJanelaDevolucao();
    const avisarErro = (mensagem) => mostrarAviso(janela, { tipo: "erro", titulo: "Devolução não registrada", mensagem });

    if (await negarSemPermissao(janela, "locacoes_gerenciar")) return { sucesso: false };

    const taxas = lerDinheiro(dados.taxas_extras) || 0;
    const defeito = dados.com_defeito ? texto(dados.defeito) : "";

    if (!dados.data_devolucao) {
      await avisarErro("Informe a data da devolução.");
      return { sucesso: false };
    }
    if (inteiroOuNulo(dados.km_retorno) === null) {
      await avisarErro("Informe a quilometragem de retorno (o número do painel do carro).");
      return { sucesso: false };
    }
    if (taxas > 0 && texto(dados.taxas_motivo).length < 3) {
      await avisarErro(MENSAGENS_DO_BANCO.taxas_com_motivo);
      return { sucesso: false };
    }
    if (dados.com_defeito && defeito.length < 5) {
      await avisarErro("Descreva o defeito encontrado (o carro vai direto para a manutenção).");
      return { sucesso: false };
    }

    const { data: resumo, error } = await supabase.rpc("registrar_devolucao", {
      p_locacao_id: Number(dados.locacao_id),
      p_data_devolucao: dados.data_devolucao,
      p_observacoes: texto(dados.observacoes) || null,
      p_defeito: defeito || null,
      p_oficina: dados.com_defeito ? texto(dados.oficina) || null : null,
      p_km_retorno: inteiroOuNulo(dados.km_retorno),
      p_taxas_extras: taxas,
      p_taxas_motivo: taxas > 0 ? texto(dados.taxas_motivo) : null,
    });

    if (error) {
      console.error("Banco recusou a devolução:", error.code, error.message);
      await avisarErro(traduzirErroBanco(error, MENSAGENS_DO_BANCO));
      return { sucesso: false };
    }

    avisarQueLocacoesMudaram();

    // O banco devolve o "recibo" da conta: mostramos para quem atende
    const linhas = [
      `${resumo.dias} diária(s): ${dinheiro(resumo.valor_diarias)}`,
      resumo.dias_atraso > 0 ? `Atraso: ${resumo.dias_atraso} dia(s) (já incluído nas diárias)` : null,
      resumo.taxas_extras > 0 ? `Taxas extras: ${dinheiro(resumo.taxas_extras)}` : null,
      resumo.km_rodados != null ? `Rodou ${Number(resumo.km_rodados).toLocaleString("pt-BR")} km` : null,
      `TOTAL: ${dinheiro(resumo.valor_total)}`,
      resumo.status_veiculo === "Em manutenção" ? "O carro foi enviado para a manutenção." : "O carro voltou para a frota.",
    ].filter(Boolean);

    await mostrarAviso(janela, { tipo: "sucesso", titulo: "Devolução registrada", mensagem: linhas.join("\n") });
    return { sucesso: true, resumo };
  });

  // ---------------------------------------------------- CANCELAMENTO
  ipcMain.handle("cancelar-locacao", async (event, { locacao_id, motivo }) => {
    const janela = obterJanelaCancelamento();
    if (await negarSemPermissao(janela, "locacoes_cancelar")) return { sucesso: false };

    if (texto(motivo).length < 5) {
      await mostrarAviso(janela, { tipo: "erro", titulo: "Motivo obrigatório", mensagem: "Informe o motivo do cancelamento." });
      return { sucesso: false };
    }

    const { error } = await supabase.rpc("cancelar_aluguel", {
      p_locacao_id: Number(locacao_id),
      p_motivo: texto(motivo),
    });

    if (error) {
      console.error("Banco recusou o cancelamento:", error.code, error.message);
      await mostrarAviso(janela, { tipo: "erro", titulo: "Não foi possível cancelar", mensagem: traduzirErroBanco(error) });
      return { sucesso: false };
    }

    avisarQueLocacoesMudaram();
    await mostrarAviso(janela, {
      tipo: "sucesso",
      titulo: "Aluguel cancelado",
      mensagem: "O aluguel foi cancelado (sem cobrança) e o carro voltou para a frota.",
    });
    return { sucesso: true };
  });
}

module.exports = { registrarIpcLocacoes };
