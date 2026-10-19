// =====================================================================
//  IPC da manutenção (ida para a oficina e liberação)
// ---------------------------------------------------------------------
//  Igual às locações: o desktop NÃO grava direto na tabela. Ele chama
//  as funções do banco, as mesmas que a web e o celular usam:
//
//    abrir_manutencao    → registra a ida para a oficina (com a vistoria
//                          opcional) e marca o carro "Em manutenção"
//    concluir_manutencao → registra serviço, custo e data de liberação
//                          e devolve o carro para a frota (Disponível)
//
//  O custo entra no Financeiro das 3 plataformas (visão
//  vw_faturamento_mensal). O carro que volta de um aluguel com defeito
//  NÃO passa por aqui: ele vai para a oficina na própria devolução.
// =====================================================================

const { ipcMain, BrowserWindow } = require("electron");
const supabase = require("../supabase");
const { temPermissao } = require("../sessao");
const { traduzirErroBanco } = require("../erros-banco");
const { lerDinheiro } = require("./frota");

// As colunas, com o carro e as pessoas "penduradas". A tabela aponta para
// perfis DUAS vezes (quem enviou e quem liberou), por isso cada ligação
// leva o nome da regra do banco (o mesmo jeito da web e do celular).
const COLUNAS =
  "id, veiculo_id, locacao_id, defeito, oficina, data_entrada, previsao_liberacao, data_liberacao, " +
  "servico_realizado, custo, status, motor_ok, freios_ok, pneus_ok, oleo_ok, " +
  "veiculos(marca, modelo, placa), " +
  "abriu:perfis!manutencoes_usuario_id_fkey(nome), " +
  "concluiu:perfis!manutencoes_concluido_por_fkey(nome)";

const MENSAGENS_DO_BANCO = {
  manutencoes_defeito_check: "Descreva o defeito (pelo menos 5 letras).",
  manutencoes_check: "A previsão de liberação não pode ser antes da entrada.",
  uk_manutencao_aberta_por_veiculo: "Este carro já está na oficina.",
};

const texto = (valor) => String(valor ?? "").trim();

// O checklist chega da tela como "ok" / "problema" / "" (não conferido).
// No banco vira true / false / null (null = não conferido).
function itemDoChecklist(valor) {
  if (valor === "ok") return true;
  if (valor === "problema") return false;
  return null;
}

// "deps" vem do index.js
function registrarIpcManutencoes(deps) {
  const { mostrarAviso, obterJanelaEnviar, obterJanelaLiberar } = deps;

  // Mexe na manutenção E no carro: as duas telas precisam atualizar
  function avisarQueManutencoesMudaram() {
    BrowserWindow.getAllWindows().forEach((janela) => {
      if (janela.isDestroyed()) return;
      janela.webContents.send("manutencoes-atualizadas");
      janela.webContents.send("frota-atualizada");
    });
  }

  async function negarSemPermissao(janela) {
    if (temPermissao("manutencoes")) return false;
    await mostrarAviso(janela, {
      tipo: "erro",
      titulo: "Permissão negada",
      mensagem: "Você não tem permissão para fazer isso. Fale com o responsável pela locadora.",
    });
    return true;
  }

  // ---------------------------------------------------------- LISTAR
  // emAndamento = true → carros na oficina | false → histórico (concluídas)
  ipcMain.handle("buscar-manutencoes", async (event, emAndamento) => {
    const { data, error } = await supabase
      .from("manutencoes")
      .select(COLUNAS)
      .eq("status", emAndamento ? "Em andamento" : "Concluída")
      // Na oficina: quem entrou primeiro em cima. Histórico: a mais recente em cima.
      .order(emAndamento ? "data_entrada" : "data_liberacao", { ascending: !!emAndamento })
      .limit(300);

    if (error) {
      console.error("Erro ao buscar manutenções:", error.message);
      return [];
    }
    return data;
  });

  // ------------------------------------------------ ENVIAR P/ OFICINA
  ipcMain.handle("abrir-manutencao", async (event, dados) => {
    const janela = obterJanelaEnviar();
    const avisarErro = (mensagem) => mostrarAviso(janela, { tipo: "erro", titulo: "Não foi possível enviar", mensagem });

    if (await negarSemPermissao(janela)) return { sucesso: false };

    if (!dados.veiculo_id) {
      await avisarErro("Escolha o veículo.");
      return { sucesso: false };
    }
    if (texto(dados.defeito).length < 5) {
      await avisarErro("Descreva o defeito ou o motivo (pelo menos 5 letras).");
      return { sucesso: false };
    }

    // Vistoria desligada = os 4 itens "não conferidos" (null)
    const vistoria = dados.fazer_vistoria ? dados.checklist || {} : {};

    // As outras regras (carro precisa estar Disponível, datas) quem
    // confere é a função do banco.
    const { data: idNovo, error } = await supabase.rpc("abrir_manutencao", {
      p_veiculo_id: Number(dados.veiculo_id),
      p_defeito: texto(dados.defeito),
      p_oficina: texto(dados.oficina) || null,
      p_data_entrada: dados.data_entrada || null,
      p_previsao: dados.previsao || null,
      p_motor_ok: itemDoChecklist(vistoria.motor),
      p_freios_ok: itemDoChecklist(vistoria.freios),
      p_pneus_ok: itemDoChecklist(vistoria.pneus),
      p_oleo_ok: itemDoChecklist(vistoria.oleo),
    });

    if (error) {
      console.error("Banco recusou a manutenção:", error.code, error.message);
      await avisarErro(traduzirErroBanco(error, MENSAGENS_DO_BANCO));
      return { sucesso: false };
    }

    avisarQueManutencoesMudaram();
    await mostrarAviso(janela, {
      tipo: "sucesso",
      titulo: "Enviado para a oficina",
      mensagem: `Manutenção #${idNovo} aberta. O carro fica bloqueado para aluguel até ser liberado.`,
    });
    return { sucesso: true, id: idNovo };
  });

  // ---------------------------------------------------------- LIBERAR
  ipcMain.handle("concluir-manutencao", async (event, dados) => {
    const janela = obterJanelaLiberar();
    const avisarErro = (mensagem) => mostrarAviso(janela, { tipo: "erro", titulo: "Não foi possível liberar", mensagem });

    if (await negarSemPermissao(janela)) return { sucesso: false };

    const custo = lerDinheiro(dados.custo);

    if (texto(dados.servico).length < 5) {
      await avisarErro("Descreva o serviço realizado (pelo menos 5 letras).");
      return { sucesso: false };
    }
    if (custo === null || custo < 0) {
      await avisarErro("Informe o custo do reparo (use 0 se foi na garantia).");
      return { sucesso: false };
    }
    if (!dados.data_liberacao) {
      await avisarErro("Informe a data da liberação.");
      return { sucesso: false };
    }

    const { error } = await supabase.rpc("concluir_manutencao", {
      p_manutencao_id: Number(dados.manutencao_id),
      p_data_liberacao: dados.data_liberacao,
      p_servico: texto(dados.servico),
      p_custo: custo,
    });

    if (error) {
      console.error("Banco recusou a liberação:", error.code, error.message);
      await avisarErro(traduzirErroBanco(error, MENSAGENS_DO_BANCO));
      return { sucesso: false };
    }

    avisarQueManutencoesMudaram();
    await mostrarAviso(janela, {
      tipo: "sucesso",
      titulo: "Veículo liberado",
      mensagem: `O carro voltou para a frota como Disponível. Custo de ${custo.toLocaleString("pt-BR", {
        style: "currency",
        currency: "BRL",
      })} lançado no Financeiro.`,
    });
    return { sucesso: true };
  });
}

module.exports = { registrarIpcManutencoes };
