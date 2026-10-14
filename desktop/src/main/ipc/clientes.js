// =====================================================================
//  IPC dos clientes
// ---------------------------------------------------------------------
//  Quem confere o quê (as mesmas regras da web e do celular):
//
//  - A TELA ajuda quem digita: máscara no CPF e no telefone.
//  - ESTE ARQUIVO limpa os dados (só números no CPF, CNH e telefone),
//    confere o que é simples (campos vazios, data da CNH) e, se o banco
//    recusar, traduz o motivo para português.
//  - O BANCO é o juiz final: confere os dígitos do CPF e da CNH, o DDD
//    do telefone, e-mail, duplicados e se dá para arquivar.
//
//  Nada é apagado: "arquivar" só esconde o cliente das listas. O
//  histórico de locações continua.
// =====================================================================

const { ipcMain, BrowserWindow } = require("electron");
const supabase = require("../supabase");
const { temPermissao } = require("../sessao");
const { traduzirErroBanco, nomeDaRegra } = require("../erros-banco");

// As colunas que a tela usa (nunca "select *": só o que precisa)
const COLUNAS = "id, nome, cpf, cnh, cnh_validade, email, telefone, endereco, arquivado";

// Frases para cada regra do banco (nomes em banco/01 e banco/02)
const MENSAGENS_DO_BANCO = {
  clientes_nome_check: "Informe o nome completo (nome e sobrenome).",
  clientes_cpf_check: "CPF inválido. Confira os números digitados.",
  clientes_cnh_check: "Número de CNH inválido. São 11 números.",
  clientes_email_check: "Digite um e-mail válido.",
  clientes_telefone_check: "Telefone inválido. Informe DDD + número, ex.: (19) 99999-9999.",
  clientes_endereco_check: "O endereço pode ter no máximo 200 caracteres.",
};

// Para o aviso de duplicado: qual coluna cada regra UNIQUE protege
const DUPLICADOS = {
  clientes_cpf_key: { coluna: "cpf", rotulo: "Este CPF" },
  clientes_cnh_key: { coluna: "cnh", rotulo: "Esta CNH" },
  clientes_email_key: { coluna: "email", rotulo: "Este e-mail" },
};

const soDigitos = (texto) => String(texto || "").replace(/\D/g, "");

// "AAAA-MM-DD" de hoje no horário do computador, mais ou menos N anos.
// (toISOString sozinho dá a data de Londres: depois das 21h no Brasil
// ele já diria "amanhã". Por isso descontamos o fuso antes.)
function dataDaqui(anos = 0) {
  const d = new Date();
  d.setFullYear(d.getFullYear() + anos);
  d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
  return d.toISOString().slice(0, 10);
}

// Limpa os dados e confere o que é simples. Devolve { cliente, erro }.
function prepararCliente(dados) {
  const cliente = {
    nome: String(dados.nome || "").trim().replace(/\s+/g, " "),
    cpf: soDigitos(dados.cpf),
    cnh: soDigitos(dados.cnh),
    cnh_validade: String(dados.cnh_validade || ""),
    email: String(dados.email || "").trim().toLowerCase(),
    telefone: soDigitos(dados.telefone),
    endereco: String(dados.endereco || "").trim().replace(/\s+/g, " ") || null,
  };

  if (!/^\S+\s+\S+/.test(cliente.nome)) return { erro: "Informe o nome completo (nome e sobrenome)." };
  if (cliente.cpf.length !== 11) return { erro: "O CPF tem 11 números." };
  if (cliente.cnh.length !== 11) return { erro: "A CNH tem 11 números." };
  if (!/^\d{4}-\d{2}-\d{2}$/.test(cliente.cnh_validade)) return { erro: "Informe a validade da CNH." };
  if (cliente.cnh_validade < dataDaqui(-10) || cliente.cnh_validade > dataDaqui(15)) {
    return { erro: "Validade da CNH fora do esperado. Confira a data." };
  }
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(cliente.email)) return { erro: "Digite um e-mail válido." };
  if (cliente.telefone.length < 10 || cliente.telefone.length > 11) {
    return { erro: "Telefone inválido. Informe DDD + número, ex.: (19) 99999-9999." };
  }

  return { cliente };
}

// CPF/CNH/e-mail repetido: diz DE QUEM é (igual à web). Se o dono estiver
// arquivado, sugere reativar em vez de cadastrar de novo.
async function mensagemDeDuplicado(regra, cliente, idAtual) {
  const { coluna, rotulo } = DUPLICADOS[regra];
  const { data: dono } = await supabase
    .from("clientes")
    .select("id, nome, arquivado")
    .eq(coluna, cliente[coluna])
    .neq("id", idAtual || 0)
    .maybeSingle();

  if (!dono) return `${rotulo} já está cadastrado.`;
  if (dono.arquivado) {
    return `${rotulo} pertence a ${dono.nome}, que está arquivado. Reative esse cadastro em vez de criar outro.`;
  }
  return `${rotulo} já pertence ao cliente ${dono.nome}.`;
}

// Quantos dias faltam para a data (negativo = já passou)
function diasAte(dataTexto) {
  // As duas datas no mesmo formato "AAAA-MM-DD": a conta fica exata
  return Math.round((new Date(dataTexto) - new Date(dataDaqui())) / 86400000);
}

// "deps" vem do index.js: mostrarAviso, obterJanelaDashboard, obterJanelaCliente
function registrarIpcClientes(deps) {
  const { mostrarAviso, obterJanelaDashboard, obterJanelaCliente } = deps;

  function avisarQueClientesMudaram() {
    BrowserWindow.getAllWindows().forEach((janela) => {
      if (!janela.isDestroyed()) janela.webContents.send("clientes-atualizados");
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
  async function listarClientes(arquivados) {
    const { data, error } = await supabase
      .from("clientes")
      .select(COLUNAS)
      .eq("arquivado", arquivados)
      .order("nome", { ascending: true });

    if (error) {
      console.error("Erro ao buscar clientes:", error.message);
      return [];
    }
    return data;
  }

  ipcMain.handle("buscar-clientes", () => listarClientes(false));
  ipcMain.handle("buscar-clientes-arquivados", () => listarClientes(true));

  // --------------------------------------------- CADASTRAR OU EDITAR
  ipcMain.handle("salvar-cliente", async (event, dados) => {
    const janela = obterJanelaCliente();
    const avisarErro = (mensagem) => mostrarAviso(janela, { tipo: "erro", titulo: "Não foi possível salvar", mensagem });

    try {
      if (await negarSemPermissao(janela, "clientes_gerenciar")) return { sucesso: false };

      const { cliente, erro } = prepararCliente(dados);
      if (erro) {
        await avisarErro(erro);
        return { sucesso: false };
      }

      // Com id = editar. Sem id = cadastrar. Os dois mandam TODOS os campos.
      const { error } = dados.id
        ? await supabase.from("clientes").update(cliente).eq("id", dados.id)
        : await supabase.from("clientes").insert(cliente);

      if (error) {
        console.error("Banco recusou o cliente:", error.code, error.message);
        const regra = nomeDaRegra(error);
        const mensagem = DUPLICADOS[regra]
          ? await mensagemDeDuplicado(regra, cliente, dados.id)
          : traduzirErroBanco(error, MENSAGENS_DO_BANCO);
        await avisarErro(mensagem);
        return { sucesso: false };
      }

      avisarQueClientesMudaram();

      // Salva mesmo com a CNH vencida (o cliente pode estar renovando),
      // mas avisa: o banco não deixa alugar enquanto não atualizar.
      const dias = diasAte(cliente.cnh_validade);
      const avisoCnh = dias < 0
        ? " Atenção: a CNH está vencida. Ele só poderá alugar depois de atualizar a validade."
        : dias <= 30
          ? ` Atenção: a CNH vence em ${dias} dia(s).`
          : "";

      await mostrarAviso(janela, {
        tipo: avisoCnh ? "perigo" : "sucesso",
        titulo: dados.id ? "Cliente atualizado" : "Cliente cadastrado",
        mensagem: `O cadastro de ${cliente.nome} foi salvo.${avisoCnh}`,
      });
      return { sucesso: true };
    } catch (erro) {
      console.error("Erro inesperado ao salvar cliente:", erro);
      await avisarErro("Algo deu errado ao salvar. Tente novamente.");
      return { sucesso: false };
    }
  });

  // ------------------------------------------- ARQUIVAR / REATIVAR
  // Quem confere se o cliente tem aluguel em andamento é o banco
  // (tg_clientes_antes). Se tiver, ele recusa com uma frase pronta.
  async function mudarArquivado(id, arquivar) {
    const janela = obterJanelaDashboard();
    if (await negarSemPermissao(janela, "clientes_arquivar")) return { sucesso: false };

    const { data, error } = await supabase
      .from("clientes")
      .update({ arquivado: arquivar })
      .eq("id", id)
      .select("nome, cnh_validade")
      .single();

    if (error) {
      console.error("Erro ao arquivar/reativar cliente:", error.message);
      await mostrarAviso(janela, {
        tipo: "erro",
        titulo: arquivar ? "Não foi possível arquivar" : "Não foi possível reativar",
        mensagem: traduzirErroBanco(error, MENSAGENS_DO_BANCO),
      });
      return { sucesso: false };
    }

    avisarQueClientesMudaram();

    const cnhVencida = !arquivar && diasAte(data.cnh_validade) < 0;
    await mostrarAviso(janela, {
      tipo: cnhVencida ? "perigo" : "sucesso",
      titulo: arquivar ? "Cliente arquivado" : "Cliente reativado",
      mensagem: arquivar
        ? `${data.nome} saiu da lista de clientes. O histórico de locações continua guardado.`
        : `${data.nome} voltou para a lista de clientes.` +
          (cnhVencida ? " A CNH está vencida: atualize a validade antes de um novo aluguel." : ""),
    });
    return { sucesso: true };
  }

  ipcMain.handle("arquivar-cliente", (event, id) => mudarArquivado(id, true));
  ipcMain.handle("reativar-cliente", (event, id) => mudarArquivado(id, false));
}

module.exports = { registrarIpcClientes, prepararCliente };
