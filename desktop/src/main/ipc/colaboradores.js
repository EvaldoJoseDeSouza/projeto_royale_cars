// =====================================================================
//  IPC dos colaboradores (a equipe da locadora)
// ---------------------------------------------------------------------
//  Só o chefe mexe aqui. É o mesmo funcionamento da web:
//
//  - CADASTRAR: o chefe informa nome, e-mail, cargo e permissões. O
//    sistema gera uma SENHA TEMPORÁRIA, que aparece uma única vez. No
//    primeiro acesso a pessoa é obrigada a criar a própria senha.
//  - REDEFINIR SENHA: gera outra senha temporária (a antiga para de valer).
//  - DESATIVAR / ATIVAR: corta ou devolve o acesso. Nada é apagado, o
//    histórico continua no banco.
//
//  Por que a Edge Function "admin-usuarios"?
//  Criar um login no Supabase Auth, trocar a senha de OUTRA pessoa ou
//  bloquear um login precisa da chave de serviço (service_role). Essa
//  chave abre tudo, então ela NUNCA pode ficar dentro do app. Ela fica
//  guardada no servidor do Supabase, dentro da função. O app só pede:
//  "cria esta pessoa", e a função confere se quem pediu é o chefe.
// =====================================================================

const { ipcMain, BrowserWindow } = require("electron");
const supabase = require("../supabase");
const { temPermissao } = require("../sessao");

// As 13 permissões e o que cada uma liga junto. É a mesma lista da tela
// (renderer/compartilhado/permissoes.js), escrita de novo de propósito:
// o processo principal é o "fiscal" e não confia no que a tela mandou.
const PERMISSOES = [
  "clientes_ver", "clientes_gerenciar", "clientes_arquivar",
  "veiculos_ver", "veiculos_gerenciar", "veiculos_arquivar",
  "locacoes_ver", "locacoes_gerenciar", "locacoes_cancelar",
  "manutencoes", "financeiro", "relatorios", "relatorios_financeiros",
];

const DEPENDENCIAS = {
  clientes_gerenciar: ["clientes_ver"],
  clientes_arquivar: ["clientes_ver"],
  veiculos_gerenciar: ["veiculos_ver"],
  veiculos_arquivar: ["veiculos_ver"],
  locacoes_gerenciar: ["locacoes_ver", "clientes_ver", "veiculos_ver"],
  locacoes_cancelar: ["locacoes_ver"],
  manutencoes: ["veiculos_ver"],
  relatorios_financeiros: ["relatorios"],
};

// Joga fora chaves que não existem e liga as dependências que faltarem
function limparPermissoes(lista) {
  const marcadas = (Array.isArray(lista) ? lista : []).filter((p) => PERMISSOES.includes(p));
  const todas = new Set(marcadas);
  marcadas.forEach((p) => (DEPENDENCIAS[p] || []).forEach((d) => todas.add(d)));
  return [...todas];
}

// Chama a Edge Function. Devolve { dados } quando deu certo ou { erro }
// com a mensagem que a função escreveu (ex.: "Já existe um usuário com
// este e-mail."). O token do chefe logado vai junto automaticamente.
async function chamarAdmin(corpo) {
  const { data, error } = await supabase.functions.invoke("admin-usuarios", { body: corpo });

  if (error) {
    // Quando a função responde com erro (400, 403...), a mensagem vem
    // dentro da resposta. Se nem isso der para ler, a internet caiu ou
    // a função não está publicada.
    let mensagem = "Não foi possível falar com o servidor. Verifique a internet e tente de novo.";
    try {
      const corpoErro = await error.context.json();
      if (corpoErro && corpoErro.erro) mensagem = corpoErro.erro;
    } catch (e) {
      console.error("Erro ao chamar admin-usuarios:", error.message);
    }
    return { erro: mensagem };
  }

  if (data && data.erro) return { erro: data.erro };
  return { dados: data };
}

// "deps" vem do index.js:
//   mostrarAviso, obterJanelaDashboard, obterJanelaColaborador,
//   mostrarSenhaTemporaria({ nome, email, senha })
function registrarIpcColaboradores(deps) {
  const { mostrarAviso, obterJanelaDashboard, obterJanelaColaborador, mostrarSenhaTemporaria } = deps;

  // Avisa todas as janelas abertas que a lista da equipe mudou
  function avisarQueEquipeMudou() {
    BrowserWindow.getAllWindows().forEach((janela) => {
      if (!janela.isDestroyed()) janela.webContents.send("colaboradores-atualizados");
    });
  }

  async function negarSeNaoForChefe(janela) {
    if (temPermissao("administracao")) return false;
    await mostrarAviso(janela, {
      tipo: "erro",
      titulo: "Permissão negada",
      mensagem: "Só o chefe pode cuidar da equipe.",
    });
    return true;
  }

  // ---------------------------------------------------------- LISTAR
  // ativos = true → equipe ativa. ativos = false → desativados.
  async function listarEquipe(ativos) {
    if (!temPermissao("administracao")) return [];

    // "usuario_permissoes(permissao)" pede ao Supabase para trazer junto as
    // permissões de cada pessoa (as duas tabelas são ligadas pelo id).
    const { data, error } = await supabase
      .from("perfis")
      .select("id, nome, email, cargo, ativo, trocar_senha, ultimo_acesso, usuario_permissoes(permissao)")
      .eq("ativo", ativos)
      .order("nome", { ascending: true });

    if (error) {
      console.error("Erro ao buscar a equipe:", error.message);
      return [];
    }

    // Transforma [{permissao:'clientes_ver'}, ...] em ['clientes_ver', ...]
    return data.map(({ usuario_permissoes, ...pessoa }) => ({
      ...pessoa,
      permissoes: (usuario_permissoes || []).map((linha) => linha.permissao),
    }));
  }

  ipcMain.handle("buscar-colaboradores", () => listarEquipe(true));
  ipcMain.handle("buscar-colaboradores-desativados", () => listarEquipe(false));

  // --------------------------------------------- CADASTRAR OU EDITAR
  ipcMain.handle("salvar-colaborador", async (event, dados) => {
    const janela = obterJanelaColaborador();
    const avisar = (titulo, mensagem) => mostrarAviso(janela, { tipo: "erro", titulo, mensagem });

    try {
      if (await negarSeNaoForChefe(janela)) return { sucesso: false };

      const editando = Boolean(dados.id);
      const nome = String(dados.nome || "").trim().replace(/\s+/g, " ");
      const email = String(dados.email || "").trim().toLowerCase();
      const cargo = String(dados.cargo || "");
      const permissoes = limparPermissoes(dados.permissoes);

      // Mesmas regras da web e da Edge Function
      if (!/^\S+\s+\S+/.test(nome) || nome.length > 100) {
        await avisar("Nome incompleto", "Informe nome e sobrenome.");
        return { sucesso: false };
      }
      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
        await avisar("E-mail inválido", "Digite um e-mail válido (ex.: nome@royalecars.com.br).");
        return { sucesso: false };
      }
      if (!["gerente", "funcionario"].includes(cargo)) {
        await avisar("Cargo obrigatório", "Escolha o cargo: Funcionário ou Gerente.");
        return { sucesso: false };
      }
      if (permissoes.length === 0) {
        await avisar("Sem permissões", "Marque pelo menos uma permissão (ou escolha um modelo).");
        return { sucesso: false };
      }

      // ---------- CADASTRAR: tudo pela Edge Function
      if (!editando) {
        const { dados: criado, erro } = await chamarAdmin({ acao: "criar", nome, email, cargo, permissoes });
        if (erro) {
          await avisar("Não foi possível cadastrar", erro);
          return { sucesso: false };
        }

        avisarQueEquipeMudou();

        // Fecha o cadastro e mostra a senha (ela só aparece agora)
        if (janela && !janela.isDestroyed()) janela.close();
        mostrarSenhaTemporaria({ nome, email, senha: criado.senha_temporaria });
        return { sucesso: true };
      }

      // ---------- EDITAR
      // 1) E-mail de login mudou? Isso mexe no Supabase Auth: Edge Function.
      const { data: antes, error: erroBusca } = await supabase
        .from("perfis")
        .select("email, cargo, usuario_permissoes(permissao)")
        .eq("id", dados.id)
        .maybeSingle();

      if (erroBusca || !antes || antes.cargo === "chefe") {
        await avisar("Não encontrado", "Esta pessoa não foi encontrada. Atualize a lista e tente de novo.");
        return { sucesso: false };
      }

      if (antes.email !== email) {
        const { erro } = await chamarAdmin({ acao: "alterar_email", usuario_id: dados.id, email });
        if (erro) {
          await avisar("E-mail não alterado", erro);
          return { sucesso: false };
        }
      }

      // 2) Nome e cargo: o chefe pode gravar direto (o banco confere)
      const { error: erroPerfil } = await supabase
        .from("perfis")
        .update({ nome, cargo })
        .eq("id", dados.id);

      if (erroPerfil) {
        console.error("Erro ao salvar perfil:", erroPerfil.message);
        await avisar("Erro ao salvar", "Não foi possível salvar os dados. Tente novamente.");
        return { sucesso: false };
      }

      // 3) Permissões: tira as desmarcadas e coloca as novas.
      //    (Só mexe no que mudou: assim o histórico do banco registra
      //    exatamente "Liberou X" e "Retirou Y".)
      const tinha = (antes.usuario_permissoes || []).map((linha) => linha.permissao);
      const tirar = tinha.filter((p) => !permissoes.includes(p));
      const colocar = permissoes.filter((p) => !tinha.includes(p));

      if (tirar.length > 0) {
        const { error } = await supabase
          .from("usuario_permissoes")
          .delete()
          .eq("usuario_id", dados.id)
          .in("permissao", tirar);
        if (error) throw error;
      }

      if (colocar.length > 0) {
        const { error } = await supabase
          .from("usuario_permissoes")
          .insert(colocar.map((permissao) => ({ usuario_id: dados.id, permissao })));
        if (error) throw error;
      }

      avisarQueEquipeMudou();
      await mostrarAviso(janela, {
        tipo: "sucesso",
        titulo: "Acesso atualizado",
        mensagem: `O acesso de ${nome} foi atualizado. As mudanças valem no próximo login.`,
      });
      return { sucesso: true };
    } catch (erro) {
      console.error("Erro inesperado ao salvar colaborador:", erro);
      await avisar("Erro ao salvar", "Algo deu errado ao salvar. Tente novamente.");
      return { sucesso: false };
    }
  });

  // -------------------------------------------------- REDEFINIR SENHA
  // A confirmação ("Gerar nova senha para Fulano?") já foi feita na tela.
  ipcMain.handle("redefinir-senha-colaborador", async (event, { id, nome }) => {
    const janela = obterJanelaDashboard();
    if (await negarSeNaoForChefe(janela)) return { sucesso: false };

    const { dados, erro } = await chamarAdmin({ acao: "redefinir_senha", usuario_id: id });
    if (erro) {
      await mostrarAviso(janela, { tipo: "erro", titulo: "Senha não redefinida", mensagem: erro });
      return { sucesso: false };
    }

    avisarQueEquipeMudou(); // o cartão passa a mostrar "aguardando troca de senha"
    mostrarSenhaTemporaria({ nome, senha: dados.senha_temporaria });
    return { sucesso: true };
  });

  // ------------------------------------------------ DESATIVAR / ATIVAR
  async function mudarSituacao(id, nome, ativar) {
    const janela = obterJanelaDashboard();
    if (await negarSeNaoForChefe(janela)) return { sucesso: false };

    const { erro } = await chamarAdmin({ acao: ativar ? "ativar" : "desativar", usuario_id: id });
    if (erro) {
      await mostrarAviso(janela, { tipo: "erro", titulo: "Não foi possível alterar", mensagem: erro });
      return { sucesso: false };
    }

    avisarQueEquipeMudou();
    await mostrarAviso(janela, {
      tipo: "sucesso",
      titulo: ativar ? "Acesso reativado" : "Acesso desativado",
      mensagem: ativar
        ? `${nome} voltou a ter acesso ao sistema.`
        : `${nome} não consegue mais entrar no sistema. O histórico continua guardado.`,
    });
    return { sucesso: true };
  }

  ipcMain.handle("desativar-colaborador", (event, { id, nome }) => mudarSituacao(id, nome, false));
  ipcMain.handle("ativar-colaborador", (event, { id, nome }) => mudarSituacao(id, nome, true));
}

module.exports = { registrarIpcColaboradores, limparPermissoes };
