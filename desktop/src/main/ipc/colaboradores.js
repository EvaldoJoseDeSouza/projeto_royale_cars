const { ipcMain, BrowserWindow } = require("electron");
const supabase = require("../supabase");
const { temPermissao } = require("../sessao");

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

function limparPermissoes(lista) {
  const marcadas = (Array.isArray(lista) ? lista : []).filter((p) => PERMISSOES.includes(p));
  const todas = new Set(marcadas);
  marcadas.forEach((p) => (DEPENDENCIAS[p] || []).forEach((d) => todas.add(d)));
  return [...todas];
}

async function chamarAdmin(corpo) {
  const { data, error } = await supabase.functions.invoke("admin-usuarios", { body: corpo });

  if (error) {
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

function registrarIpcColaboradores(deps) {
  const { mostrarAviso, obterJanelaDashboard, obterJanelaColaborador, mostrarSenhaTemporaria } = deps;
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
  async function listarEquipe(ativos) {
    if (!temPermissao("administracao")) return [];
    const { data, error } = await supabase
      .from("perfis")
      .select("id, nome, email, cargo, ativo, trocar_senha, ultimo_acesso, usuario_permissoes(permissao)")
      .eq("ativo", ativos)
      .order("nome", { ascending: true });

    if (error) {
      console.error("Erro ao buscar a equipe:", error.message);
      return [];
    }

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

        if (janela && !janela.isDestroyed()) janela.close();
        mostrarSenhaTemporaria({ nome, email, senha: criado.senha_temporaria });
        return { sucesso: true };
      }

      // ---------- EDITAR
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

      const { error: erroPerfil } = await supabase
        .from("perfis")
        .update({ nome, cargo })
        .eq("id", dados.id);

      if (erroPerfil) {
        console.error("Erro ao salvar perfil:", erroPerfil.message);
        await avisar("Erro ao salvar", "Não foi possível salvar os dados. Tente novamente.");
        return { sucesso: false };
      }

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
  ipcMain.handle("redefinir-senha-colaborador", async (event, { id, nome }) => {
    const janela = obterJanelaDashboard();
    if (await negarSeNaoForChefe(janela)) return { sucesso: false };

    const { dados, erro } = await chamarAdmin({ acao: "redefinir_senha", usuario_id: id });
    if (erro) {
      await mostrarAviso(janela, { tipo: "erro", titulo: "Senha não redefinida", mensagem: erro });
      return { sucesso: false };
    }

    avisarQueEquipeMudou(); 
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
