// =====================================================================
//  IPC da frota (veículos)
// ---------------------------------------------------------------------
//  O STATUS do veículo não é escolhido no formulário. Ele muda sozinho,
//  pelas funções do banco (igual na web e no celular):
//    Disponível    → Alugado        quando um aluguel é registrado
//    Alugado       → Disponível     quando o carro é devolvido
//    Disponível    → Em manutenção  quando vai para a oficina
//    Em manutenção → Disponível     quando a manutenção é concluída
//  Assim a frota nunca mostra "Disponível" para um carro que está na rua.
//  (Se alguém tentar mudar à mão, o banco recusa.)
//
//  Padrão de gravação: placa e chassi em maiúsculas, sem hífen nem
//  espaços ("ABC1234", "ABC1D23"). O hífen aparece só na tela.
// =====================================================================

const { ipcMain, BrowserWindow } = require("electron");
const supabase = require("../supabase");
const { temPermissao } = require("../sessao");
const { traduzirErroBanco, nomeDaRegra } = require("../erros-banco");

const COLUNAS = "id, marca, modelo, ano, placa, chassi, valor_diaria, quilometragem, imagem, status, arquivado";

// Frases para cada regra do banco (nomes em banco/01 e banco/02)
const MENSAGENS_DO_BANCO = {
  veiculos_marca_check: "Informe a marca.",
  veiculos_modelo_check: "Informe o modelo.",
  veiculos_ano_check: "Ano inválido.",
  veiculos_placa_check: "Placa inválida. Use o padrão antigo (ABC-1234) ou Mercosul (ABC1D23).",
  veiculos_chassi_check: "Chassi inválido. São 17 letras/números, sem as letras I, O e Q.",
  veiculos_valor_diaria_check: "Informe um valor de diária maior que zero.",
  veiculos_quilometragem_check: "A quilometragem não pode ser negativa.",
};

const DUPLICADOS = {
  veiculos_placa_key: { coluna: "placa", rotulo: "Esta placa" },
  veiculos_chassi_key: { coluna: "chassi", rotulo: "Este chassi" },
};

// "abc-1234" → "ABC1234"
const limparCodigo = (texto) => String(texto || "").toUpperCase().replace(/[^A-Z0-9]/g, "");

// Lê o dinheiro digitado: "R$ 1.234,56" → 1234.56  |  aceita número também
function lerDinheiro(valor) {
  if (typeof valor === "number") return valor;
  const texto = String(valor || "").replace(/[^\d,]/g, "").replace(",", ".");
  const numero = parseFloat(texto);
  return Number.isFinite(numero) ? Math.round(numero * 100) / 100 : null;
}

// Limpa e confere o que é simples. Devolve { veiculo } ou { erro }.
function prepararVeiculo(dados) {
  const anoMaximo = new Date().getFullYear() + 1;
  const veiculo = {
    marca: String(dados.marca || "").trim().replace(/\s+/g, " "),
    modelo: String(dados.modelo || "").trim().replace(/\s+/g, " "),
    ano: Number(dados.ano),
    placa: limparCodigo(dados.placa),
    chassi: limparCodigo(dados.chassi),
    valor_diaria: lerDinheiro(dados.valor_diaria),
    quilometragem: Number(String(dados.quilometragem ?? "").replace(/\D/g, "") || 0),
  };

  if (veiculo.marca.length < 2) return { erro: "Informe a marca." };
  if (veiculo.modelo.length < 1) return { erro: "Informe o modelo." };
  if (!Number.isInteger(veiculo.ano) || veiculo.ano < 1950 || veiculo.ano > anoMaximo) {
    return { erro: `Ano inválido. Use um ano entre 1950 e ${anoMaximo}.` };
  }
  if (!/^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$/.test(veiculo.placa)) return { erro: MENSAGENS_DO_BANCO.veiculos_placa_check };
  if (veiculo.chassi.length !== 17) return { erro: "O chassi tem 17 letras/números." };
  if (!veiculo.valor_diaria || veiculo.valor_diaria <= 0 || veiculo.valor_diaria > 100000) {
    return { erro: MENSAGENS_DO_BANCO.veiculos_valor_diaria_check };
  }
  if (veiculo.quilometragem > 2000000) return { erro: "Quilometragem fora do esperado. Confira o número." };

  return { veiculo };
}

// Placa ou chassi repetido: diz de qual carro é
async function mensagemDeDuplicado(regra, veiculo, idAtual) {
  const { coluna, rotulo } = DUPLICADOS[regra];
  const { data: dono } = await supabase
    .from("veiculos")
    .select("id, marca, modelo, arquivado")
    .eq(coluna, veiculo[coluna])
    .neq("id", idAtual || 0)
    .maybeSingle();

  if (!dono) return `${rotulo} já está cadastrado.`;
  const carro = `${dono.marca} ${dono.modelo}`;
  if (dono.arquivado) {
    return `${rotulo} pertence ao ${carro}, que está arquivado. Reative esse veículo em vez de cadastrar de novo.`;
  }
  return `${rotulo} já pertence ao ${carro}.`;
}

// "deps" vem do index.js: mostrarAviso, obterJanelaDashboard, obterJanelaVeiculo
function registrarIpcFrota(deps) {
  const { mostrarAviso, obterJanelaDashboard, obterJanelaVeiculo } = deps;

  function avisarQueFrotaMudou() {
    BrowserWindow.getAllWindows().forEach((janela) => {
      if (!janela.isDestroyed()) janela.webContents.send("frota-atualizada");
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
  async function listarFrota(arquivados) {
    const { data, error } = await supabase
      .from("veiculos")
      .select(COLUNAS)
      .eq("arquivado", arquivados)
      .order("marca", { ascending: true })
      .order("modelo", { ascending: true });

    if (error) {
      console.error("Erro ao buscar frota:", error.message);
      return [];
    }
    return data;
  }

  ipcMain.handle("buscar-frota", () => listarFrota(false));
  ipcMain.handle("buscar-frota-arquivada", () => listarFrota(true));

  // --------------------------------------------- CADASTRAR OU EDITAR
  ipcMain.handle("salvar-veiculo", async (event, dados) => {
    const janela = obterJanelaVeiculo();
    const avisarErro = (mensagem) => mostrarAviso(janela, { tipo: "erro", titulo: "Não foi possível salvar", mensagem });

    try {
      if (await negarSemPermissao(janela, "veiculos_gerenciar")) return { sucesso: false };

      const { veiculo, erro } = prepararVeiculo(dados);
      if (erro) {
        await avisarErro(erro);
        return { sucesso: false };
      }

      // Repare: "status" NÃO vai junto. Novo veículo entra Disponível
      // (o banco garante) e depois só os aluguéis e manutenções mudam.
      const { error } = dados.id
        ? await supabase.from("veiculos").update(veiculo).eq("id", dados.id)
        : await supabase.from("veiculos").insert(veiculo);

      if (error) {
        console.error("Banco recusou o veículo:", error.code, error.message);
        const regra = nomeDaRegra(error);
        const mensagem = DUPLICADOS[regra]
          ? await mensagemDeDuplicado(regra, veiculo, dados.id)
          : traduzirErroBanco(error, MENSAGENS_DO_BANCO);
        await avisarErro(mensagem);
        return { sucesso: false };
      }

      avisarQueFrotaMudou();
      await mostrarAviso(janela, {
        tipo: "sucesso",
        titulo: dados.id ? "Veículo atualizado" : "Veículo cadastrado",
        mensagem: dados.id
          ? `O ${veiculo.marca} ${veiculo.modelo} foi atualizado.`
          : `O ${veiculo.marca} ${veiculo.modelo} entrou na frota como Disponível.`,
      });
      return { sucesso: true };
    } catch (erro) {
      console.error("Erro inesperado ao salvar veículo:", erro);
      await avisarErro("Algo deu errado ao salvar. Tente novamente.");
      return { sucesso: false };
    }
  });

  // ------------------------------------------- ARQUIVAR / REATIVAR
  // O banco só deixa arquivar carro Disponível (não alugado nem na oficina)
  async function mudarArquivado(id, arquivar) {
    const janela = obterJanelaDashboard();
    if (await negarSemPermissao(janela, "veiculos_arquivar")) return { sucesso: false };

    const { data, error } = await supabase
      .from("veiculos")
      .update({ arquivado: arquivar })
      .eq("id", id)
      .select("marca, modelo")
      .single();

    if (error) {
      console.error("Erro ao arquivar/reativar veículo:", error.message);
      await mostrarAviso(janela, {
        tipo: "erro",
        titulo: arquivar ? "Não foi possível arquivar" : "Não foi possível reativar",
        mensagem: traduzirErroBanco(error, MENSAGENS_DO_BANCO),
      });
      return { sucesso: false };
    }

    avisarQueFrotaMudou();
    await mostrarAviso(janela, {
      tipo: "sucesso",
      titulo: arquivar ? "Veículo arquivado" : "Veículo reativado",
      mensagem: arquivar
        ? `O ${data.marca} ${data.modelo} saiu da frota. O histórico de locações continua guardado.`
        : `O ${data.marca} ${data.modelo} voltou para a frota como Disponível.`,
    });
    return { sucesso: true };
  }

  ipcMain.handle("arquivar-veiculo", (event, id) => mudarArquivado(id, true));
  ipcMain.handle("reativar-veiculo", (event, id) => mudarArquivado(id, false));
}

module.exports = { registrarIpcFrota, prepararVeiculo, lerDinheiro };
