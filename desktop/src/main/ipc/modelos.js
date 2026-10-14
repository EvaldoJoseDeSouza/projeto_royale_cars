// =====================================================================
//  IPC dos modelos de permissão (antigos "grupos")
// ---------------------------------------------------------------------
//  Como funcionava antes: cada colaborador ficava DENTRO de um grupo, e
//  as permissões vinham do grupo.
//
//  Como funciona agora (igual nas 3 plataformas): as permissões são de
//  cada PESSOA (tabela usuario_permissoes). O modelo é só um atalho:
//  "Vendedor" marca de uma vez as 5 caixas de um vendedor no cadastro.
//  Depois a pessoa pode ganhar ou perder uma caixa sem mexer no modelo.
//
//  Por isso um modelo pode ser excluído a qualquer hora: ninguém
//  "mora" dentro dele.
//
//  Quem pode mexer: só o chefe. O banco também garante isso (RLS).
// =====================================================================

const { ipcMain, BrowserWindow } = require("electron");
const supabase = require("../supabase");
const { temPermissao } = require("../sessao");

// "deps" vem do index.js: mostrarAviso, obterJanelaDashboard, obterJanelaModelo
function registrarIpcModelos(deps) {
  const { mostrarAviso, obterJanelaDashboard, obterJanelaModelo } = deps;

  // Avisa todas as janelas abertas que a lista de modelos mudou
  function avisarQueModelosMudaram() {
    BrowserWindow.getAllWindows().forEach((janela) => {
      if (!janela.isDestroyed()) janela.webContents.send("grupos-atualizados");
    });
  }

  // Só o chefe administra. "administracao" não é uma das 13 permissões,
  // então temPermissao só devolve true para o chefe (ver main/sessao.js).
  async function negarSeNaoForChefe(janela) {
    if (temPermissao("administracao")) return false;
    await mostrarAviso(janela, {
      tipo: "erro",
      titulo: "Permissão negada",
      mensagem: "Só o chefe pode alterar os modelos de permissão.",
    });
    return true;
  }

  // ---------------------------------------------------------- LISTAR
  ipcMain.handle("buscar-grupos-permissao", async () => {
    const { data, error } = await supabase
      .from("modelos_permissao")
      .select("id, nome, descricao, permissoes")
      .order("nome", { ascending: true });

    if (error) {
      console.error("Erro ao buscar modelos de permissão:", error.message);
      return [];
    }
    return data;
  });

  // ---------------------------------------------------------- SALVAR
  ipcMain.handle("salvar-grupo-permissao", async (event, dados) => {
    const janela = obterJanelaModelo();
    if (await negarSeNaoForChefe(janela)) return { sucesso: false };

    const nome = String(dados.nome || "").trim();
    if (nome.length < 2) {
      await mostrarAviso(janela, { tipo: "erro", titulo: "Nome obrigatório", mensagem: "Informe um nome para o modelo." });
      return { sucesso: false };
    }

    const registro = {
      nome,
      descricao: String(dados.descricao || "").trim() || null,
      permissoes: dados.permissoes || [],
    };

    // Com id = editar um modelo que existe. Sem id = criar um novo.
    const { error } = dados.id
      ? await supabase.from("modelos_permissao").update(registro).eq("id", dados.id)
      : await supabase.from("modelos_permissao").insert(registro);

    if (error) {
      console.error("Erro ao salvar modelo:", error.message);
      // 23505 = nome repetido (o banco não deixa dois modelos com o mesmo nome)
      const mensagem = error.code === "23505"
        ? `Já existe um modelo chamado "${nome}".`
        : "Não foi possível salvar o modelo. Tente novamente.";
      await mostrarAviso(janela, { tipo: "erro", titulo: "Erro ao salvar", mensagem });
      return { sucesso: false };
    }

    avisarQueModelosMudaram();
    await mostrarAviso(janela, {
      tipo: "sucesso",
      titulo: "Modelo salvo",
      mensagem: dados.id ? `O modelo "${nome}" foi atualizado.` : `O modelo "${nome}" foi criado.`,
    });
    return { sucesso: true };
  });

  // --------------------------------------------------------- EXCLUIR
  ipcMain.handle("excluir-grupo-permissao", async (event, idModelo) => {
    const janela = obterJanelaDashboard();
    if (await negarSeNaoForChefe(janela)) return { sucesso: false };

    const { error } = await supabase.from("modelos_permissao").delete().eq("id", idModelo);

    if (error) {
      console.error("Erro ao excluir modelo:", error.message);
      await mostrarAviso(janela, { tipo: "erro", titulo: "Erro ao excluir", mensagem: "Não foi possível excluir o modelo." });
      return { sucesso: false };
    }

    avisarQueModelosMudaram();
    await mostrarAviso(janela, { tipo: "sucesso", titulo: "Modelo excluído", mensagem: "O modelo de permissão foi excluído." });
    return { sucesso: true };
  });
}

module.exports = { registrarIpcModelos };
