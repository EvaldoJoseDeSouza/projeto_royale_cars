const { app, BrowserWindow, ipcMain, Menu, Tray, dialog } = require("electron");
const path = require("path");
const bcrypt = require("bcryptjs"); // ainda usado no cadastro de colaborador (sai no pacote 2.4)

// Conexão com o banco, sessão e conversas (IPC) do login ficam em arquivos próprios
const supabase = require("./supabase");
const { temPermissao } = require("./sessao");
const { registrarIpcSessao } = require("./ipc/sessao");
const { registrarIpcModelos } = require("./ipc/modelos");

// Retorna true (e mostra o aviso padrão) quando o usuário NÃO tem a permissão.
async function negarSemPermissao(janelaAlvo, chave) {
  if (temPermissao(chave)) return false;
  await mostrarAviso(janelaAlvo, {
    tipo: "erro",
    titulo: "Permissão Negada",
    mensagem: "Você não tem permissão para realizar esta ação.",
  });
  return true;
}

// Telas
let janelaPrincipal;
let janelaDashboard;
let janelaModalVeiculo;
let janelaModalCliente;
let janelaModalLocacao;
let janelaModalTrocarSenha;
let janelaModalConfirmacao;
let resolverConfirmacao = null;
let janelaModalGrupoPermissao;
let janelaModalColaborador;
let janelaModalRedefinirSenhaColaborador;

// Sai nos pacotes 2.5 a 2.8: o banco unificado tem uma empresa só
let idEmpresaLogada = null;

let tray = null;

function criarJanela() {
  janelaPrincipal = new BrowserWindow({
    width: 1200,
    height: 800,
    autoHideMenuBar: false,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, "../preload/preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  janelaPrincipal.maximize();
  janelaPrincipal.show();
  janelaPrincipal.loadFile(path.join(__dirname, "../renderer/telas/login/login.html"));

  janelaPrincipal.on("close", () => {
    app.isQuitting = true;
    app.quit();
  });
}

app.whenReady().then(() => {
  criarJanela();

  const templateDoMenu = [
    {
      label: "Gerenciamento",
      submenu: [
        {
          label: "Esconder Janela",
          accelerator: "CmdOrCtrl+H",
          click: () => {
            if (janelaDashboard && !janelaDashboard.isDestroyed())
              janelaDashboard.hide();
            else if (janelaPrincipal && !janelaPrincipal.isDestroyed())
              janelaPrincipal.hide();
          },
        },
        { type: "separator" },
        {
          label: "Sair do Sistema",
          role: "quit",
          accelerator: "CmdOrCtrl+Q",
        },
      ],
    },
    {
      label: "Sobre",
      submenu: [
        {
          label: "Informações do App",
          click: () => {
            dialog.showMessageBox({
              type: "info",
              title: "Royale Cars",
              message: "Sistema de Locação de Veículos v1.0",
              detail: "Desenvolvido com Electron e integração nativa ao SO.",
              buttons: ["Fechar"],
            });
          },
        },
      ],
    },
  ];

  const menuReal = Menu.buildFromTemplate(templateDoMenu);
  Menu.setApplicationMenu(menuReal);

  const iconeCaminho = path.join(__dirname, "../imagens/icone.png");
  tray = new Tray(iconeCaminho);
  tray.setToolTip("Royale Cars - Rodando em segundo plano");

  const menuDoTray = Menu.buildFromTemplate([
    {
      label: "Abrir Painel",
      click: () => {
        if (janelaDashboard && !janelaDashboard.isDestroyed()) {
          janelaDashboard.show();
        } else if (janelaPrincipal && !janelaPrincipal.isDestroyed()) {
          janelaPrincipal.show();
        }
      },
    },
    { type: "separator" },
    {
      label: "Encerrar",
      click: () => {
        app.isQuitting = true;
        app.quit();
      },
    },
  ]);

  tray.setContextMenu(menuDoTray);

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) criarJanela();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});

registrarIpcSessao({
  mostrarAviso,
  obterJanelaPrincipal: () => janelaPrincipal,
  obterJanelaTrocarSenha: () => janelaModalTrocarSenha,
});

registrarIpcModelos({
  mostrarAviso,
  obterJanelaDashboard: () => janelaDashboard,
  obterJanelaModelo: () => janelaModalGrupoPermissao,
});

ipcMain.on("abrir-modal-trocar-senha", (evento) => {
  if (janelaModalTrocarSenha) {
    janelaModalTrocarSenha.focus();
    return;
  }

  const janelaMae = BrowserWindow.fromWebContents(evento.sender);

  janelaModalTrocarSenha = new BrowserWindow({
    width: 420,
    height: 480,
    parent: janelaMae,
    modal: true,
    frame: false,
    resizable: false,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, "../preload/preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  janelaModalTrocarSenha.loadFile(
    path.join(__dirname, "../renderer/modais/trocar-senha/modalTrocarSenha.html"),
  );
  janelaModalTrocarSenha.once("ready-to-show", () =>
    janelaModalTrocarSenha.show(),
  );
  janelaModalTrocarSenha.on("closed", () => {
    janelaModalTrocarSenha = null;
  });
});

ipcMain.on("fechar-modal-trocar-senha", () => {
  if (janelaModalTrocarSenha) janelaModalTrocarSenha.close();
});

ipcMain.on("login-sucesso", () => {
  janelaDashboard = new BrowserWindow({
    width: 1200,
    height: 800,
    autoHideMenuBar: false,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, "../preload/preload.js"),
    },
  });

  janelaDashboard.maximize();
  janelaDashboard.loadFile(path.join(__dirname, "../renderer/telas/dashboard/dashboard.html"));

  janelaDashboard.on("close", (evento) => {
    if (!app.isQuitting) {
      evento.preventDefault();
      janelaDashboard.hide();
    }
  });

  janelaPrincipal.removeAllListeners("close");
  if (janelaPrincipal) janelaPrincipal.close();
});

ipcMain.on("fechar", () => {
  app.quit();
});

// ===================== MODAL DE CONFIRMAÇÃO ====================
function abrirJanelaConfirmacao(janelaMae, dadosConfimacao) {
  return new Promise((resolve) => {
    resolverConfirmacao = resolve;

    janelaModalConfirmacao = new BrowserWindow({
      width: 420,
      height: 320,
      parent: janelaMae,
      modal: true,
      frame: false,
      resizable: false,
      show: false,
      webPreferences: {
        preload: path.join(__dirname, "../preload/preload.js"),
        contextIsolation: true,
        nodeIntegration: false,
      },
    });

    janelaModalConfirmacao.loadFile(
      path.join(__dirname, "../renderer/modais/confirmacao/modalConfirmacao.html"),
    );

    janelaModalConfirmacao.webContents.once("did-finish-load", () => {
      janelaModalConfirmacao.webContents.send(
        "dados-confirmacao",
        dadosConfimacao,
      );
    });

    janelaModalConfirmacao.once("ready-to-show", () =>
      janelaModalConfirmacao.show(),
    );

    janelaModalConfirmacao.on("closed", () => {
      janelaModalConfirmacao = null;
      if (resolverConfirmacao) {
        resolverConfirmacao(false);
        resolverConfirmacao = null;
      }
    });
  });
}

ipcMain.handle("abrir-modal-confirmacao", (evento, dadosConfimacao) => {
  const janelaMae = BrowserWindow.fromWebContents(evento.sender);
  return abrirJanelaConfirmacao(janelaMae, {
    modo: "confirmar",
    ...dadosConfimacao,
  });
});

ipcMain.on("responder-confirmacao", (evento, resposta) => {
  if (resolverConfirmacao) {
    resolverConfirmacao(resposta);
    resolverConfirmacao = null;
  }
  if (janelaModalConfirmacao) janelaModalConfirmacao.close();
});

function mostrarAviso(janelaMae, { tipo, titulo, mensagem, textoConfirmar }) {
  return abrirJanelaConfirmacao(janelaMae, {
    modo: "aviso",
    titulo,
    mensagem,
    textoConfirmar: textoConfirmar || "Ok",
    tipo,
  });
}

// =========================== FROTAS ======================
ipcMain.handle("buscar-frota", async () => {
  try {
    console.log("Buscando frota filtrada para a empresa: ${idEmpresaLogada}");

    const { data, error } = await supabase
      .from("veiculos")
      .select("*")
      .eq("id_empresa", idEmpresaLogada)
      .eq("ativo", true)
      .order("id", { ascending: true });

    if (error) {
      console.error("Erro ao buscar frota:", error.message);
      return [];
    }
    return data;
  } catch (err) {
    console.error("Erro inesperado ao buscar frota:", err);
    return [];
  }
});

ipcMain.handle("buscar-frota-arquivada", async () => {
  try {
    const { data, error } = await supabase
      .from("veiculos")
      .select("*")
      .eq("id_empresa", idEmpresaLogada)
      .eq("ativo", false)
      .order("id", { ascending: true });

    if (error) {
      console.error("Erro ao buscar frota arquivada:", error.message);
      return [];
    }
    return data;
  } catch (err) {
    console.error("Erro inesperado ao buscar frota arquivada:", err);
    return [];
  }
});

ipcMain.on("abrir-modal-veiculo", (evento) => {
  if (janelaModalVeiculo) {
    janelaModalVeiculo.focus();
    return;
  }

  const janelaMae = BrowserWindow.fromWebContents(evento.sender);

  janelaModalVeiculo = new BrowserWindow({
    width: 480,
    height: 540,
    parent: janelaMae,
    modal: true,
    frame: false,
    resizable: false,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, "../preload/preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  janelaModalVeiculo.loadFile(
    path.join(__dirname, "../renderer/modais/veiculo/modalVeiculo.html"),
  );
  janelaModalVeiculo.once("ready-to-show", () => janelaModalVeiculo.show());
  janelaModalVeiculo.on("closed", () => {
    janelaModalVeiculo = null;
  });
});

ipcMain.on("fechar-modal-veiculo", () => {
  if (janelaModalVeiculo) janelaModalVeiculo.close();
});

ipcMain.handle("salvar-veiculo-banco", async (event, dadosVeiculo) => {
  try {
    if (await negarSemPermissao(janelaModalVeiculo, "veiculos_gerenciar")) return { sucesso: false };

    let query;

    if (dadosVeiculo.id) {
      query = supabase
        .from("veiculos")
        .update({
          modelo: dadosVeiculo.modelo,
          marca: dadosVeiculo.marca,
          placa: dadosVeiculo.placa,
          diaria: dadosVeiculo.diaria,
          status: dadosVeiculo.status,
        })
        .eq("id", dadosVeiculo.id);
    } else {
      const novoVeiculo = {
        ...dadosVeiculo,
        id_empresa: idEmpresaLogada,
      };

      query = supabase.from("veiculos").insert([novoVeiculo]);
    }

    const { error } = await query;

    if (error) {
      console.error("Erro ao salvar veículo no Supabase:", error.message);
      await mostrarAviso(janelaModalVeiculo, {
        tipo: "erro",
        titulo: "Erro na Operação",
        mensagem:
          `Não foi possível salvar os dados do veículo. Motivo: ${error.message}`,
      });
      return { sucesso: false, mensagem: error.message };
    }

    if (janelaDashboard && !janelaDashboard.isDestroyed()) {
      janelaDashboard.webContents.send("frota-atualizada");
    }

    await mostrarAviso(janelaModalVeiculo, {
      tipo: "sucesso",
      titulo: "Sucesso",
      mensagem: dadosVeiculo.id
        ? `O modelo ${dadosVeiculo.modelo} foi atualizado com sucesso!`
        : `O modelo ${dadosVeiculo.modelo} foi cadastrado com sucesso!`,
    });

    return { sucesso: true };
  } catch (err) {
    console.error("Erro interno ao salvar veículo:", err);
    return { sucesso: false, mensagem: "Erro interno no servidor." };
  }
});

ipcMain.handle("arquivar-veiculo-banco", async (event, idVeiculo) => {
  try {
    if (await negarSemPermissao(janelaDashboard, "veiculos_arquivar")) return { sucesso: false };

    const { data: locacoesAtivas, error: erroLocacoes } = await supabase
      .from("locacoes")
      .select("id")
      .eq("id_veiculo", idVeiculo)
      .eq("status", "Ativo");

    if (erroLocacoes) {
      console.error(
        "Erro ao verificar locações do veículo:",
        erroLocacoes.message,
      );
      await mostrarAviso(janelaDashboard, {
        tipo: "erro",
        titulo: "Erro na Verificação",
        mensagem:
          "Não foi possivel verificar as locações deste veículo. Tente novamente.",
      });
      return { sucesso: false };
    }

    if (locacoesAtivas && locacoesAtivas.length > 0) {
      await mostrarAviso(janelaDashboard, {
        tipo: "erro",
        titulo: "Não é Possível Arquivar",
        mensagem:
          "Este veículo está com uma locação ativa no momento. Finalize a locação antes de arquivá-lo.",
      });
      return { sucesso: false };
    }

    const { error } = await supabase
      .from("veiculos")
      .update({ ativo: false })
      .eq("id", idVeiculo);

    if (error) throw error;

    if (janelaDashboard && !janelaDashboard.isDestroyed()) {
      janelaDashboard.webContents.send("frota-atualizada");
    }

    await mostrarAviso(janelaDashboard, {
      tipo: "sucesso",
      titulo: "Veículo Arquivado",
      mensagem: "O veículo foi movido para os arquivos com sucesso!",
    });

    return { sucesso: true };
  } catch (err) {
    console.error("Erro ao arquivar veículo:", err.message);
    await mostrarAviso(janelaDashboard, {
      tipo: "erro",
      titulo: "Erro ao Arquivar",
      mensagem: "Não foi possivel arquivar o veículo. Tente novamente.",
    });
    return { sucesso: false, mensagem: err.message };
  }
});

ipcMain.handle("reativar-veiculo-banco", async (event, idVeiculo) => {
  try {
    if (await negarSemPermissao(janelaDashboard, "veiculos_arquivar")) return { sucesso: false };

    const { error } = await supabase
      .from("veiculos")
      .update({ ativo: true })
      .eq("id", idVeiculo);

    if (error) throw error;

    if (janelaDashboard && !janelaDashboard.isDestroyed()) {
      janelaDashboard.webContents.send("frota-atualizada");
    }

    await mostrarAviso(janelaDashboard, {
      tipo: "sucesso",
      titulo: "Veículo Reativado",
      mensagem: "O veículo voltou a aparecer nas listagens ativas!",
    });

    return { sucesso: true };
  } catch (err) {
    console.error("Erro ao reativar veículo:", err.message);
    await mostrarAviso(janelaDashboard, {
      tipo: "erro",
      titulo: "Erro ao Reativar",
      mensagem: "Não foi possível reativar o veículo. Tente novamente.",
    });
    return { sucesso: false, mensagem: err.message };
  }
});

// =============== CLIENTES ===================
ipcMain.handle("buscar-clientes", async () => {
  try {
    console.log(
      "Buscando clientes filtrandos para a empresa: ${idEmpresaLogada}",
    );

    const { data, error } = await supabase
      .from("clientes")
      .select("*")
      .eq("id_empresa", idEmpresaLogada)
      .eq("ativo", true)
      .order("nome", { ascending: true });

    if (error) {
      console.error("Erro ao buscar clientes:", error.message);
      return [];
    }
    return data;
  } catch (err) {
    console.error("Erro inesperado ao buscar clientes:", err);
    return [];
  }
});

ipcMain.handle("buscar-clientes-arquivados", async () => {
  try {
    const { data, error } = await supabase
      .from("clientes")
      .select("*")
      .eq("id_empresa", idEmpresaLogada)
      .eq("ativo", false)
      .order("nome", { ascending: true });

    if (error) {
      console.error("Erro ao buscar clientes arquivados:", error.message);
      return [];
    }
    return data;
  } catch (err) {
    console.error("Erro inesperado ao buscar clientes arquivados:", err);
    return [];
  }
});

ipcMain.on("abrir-modal-cliente", (evento) => {
  if (janelaModalCliente) {
    janelaModalCliente.focus();
    return;
  }

  const janelaMae = BrowserWindow.fromWebContents(evento.sender);

  janelaModalCliente = new BrowserWindow({
    width: 480,
    height: 580,
    parent: janelaMae,
    modal: true,
    frame: false,
    resizable: false,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, "../preload/preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  janelaModalCliente.loadFile(
    path.join(__dirname, "../renderer/modais/cliente/modalCliente.html"),
  );
  janelaModalCliente.once("ready-to-show", () => janelaModalCliente.show());
  janelaModalCliente.on("closed", () => {
    janelaModalCliente = null;
  });
});

ipcMain.on("fechar-modal-cliente", () => {
  if (janelaModalCliente) janelaModalCliente.close();
});

ipcMain.handle("salvar-cliente-banco", async (event, dadosCliente) => {
  try {
    if (await negarSemPermissao(janelaModalCliente, "clientes_gerenciar")) return { sucesso: false };

    let query;

    if (dadosCliente.id) {
      query = supabase
        .from("clientes")
        .update({
          nome: dadosCliente.nome,
          telefone: dadosCliente.telefone,
          cpf: dadosCliente.cpf,
          cnh: dadosCliente.cnh,
        })
        .eq("id", dadosCliente.id);
    } else {
      const novoCliente = {
        ...dadosCliente,
        id_empresa: idEmpresaLogada,
      };

      query = supabase.from("clientes").insert([novoCliente]);
    }

    const { error } = await query;

    if (error) {
      console.error("Erro ao salvar cliente no Supabase:", error.message);

      await mostrarAviso(janelaModalCliente, {
        tipo: "erro",
        titulo: "Erro na Operação",
        mensagem: `Não foi possível salvar os dados do cliente. Motivo: ${error.message}`,
      });

      return { sucesso: false, mensagem: error.message };
    }

    if (janelaDashboard && !janelaDashboard.isDestroyed()) {
      janelaDashboard.webContents.send("clientes-atualizados");
    }

    await mostrarAviso(janelaModalCliente, {
      tipo: "sucesso",
      titulo: "Sucesso",
      mensagem: dadosCliente.id
        ? `O cadastro de ${dadosCliente.nome} foi atualizado com sucesso!`
        : `O cadastro de ${dadosCliente.nome} foi processado com sucesso!`,
    });

    return { sucesso: true };
  } catch (err) {
    console.error("Erro interno ao salvar cliente:", err);
    return { sucesso: false, message: "Erro interno no servidor." };
  }
});

ipcMain.handle("arquivar-cliente-banco", async (event, idCliente) => {
  try {
    if (await negarSemPermissao(janelaDashboard, "clientes_arquivar")) return { sucesso: false };

    const { data: locacoesAtivas, error: erroLocacoes } = await supabase
      .from("locacoes")
      .select("id")
      .eq("id_cliente", idCliente)
      .eq("status", "Ativo");

    if (erroLocacoes) {
      console.error(
        "Erro ao verificar locações do cliente:",
        erroLocacoes.message,
      );
      await mostrarAviso(janelaDashboard, {
        tipo: "erro",
        titulo: "Erro na Verificação",
        mensagem:
          "Não foi possível verificar as locações deste cliente. Tente novamente.",
      });
      return { sucesso: false };
    }

    if (locacoesAtivas && locacoesAtivas.length > 0) {
      await mostrarAviso(janelaDashboard, {
        tipo: "erro",
        titulo: "Não é Possível Arquivar",
        mensagem:
          "Este cliente possui uma locação ativa no momento. Finalize a locação antes de arquivá-lo.",
      });
      return { sucesso: false };
    }

    const { error } = await supabase
      .from("clientes")
      .update({ ativo: false })
      .eq("id", idCliente);

    if (error) throw error;

    if (janelaDashboard && !janelaDashboard.isDestroyed()) {
      janelaDashboard.webContents.send("clientes-atualizados");
    }

    await mostrarAviso(janelaDashboard, {
      tipo: "sucesso",
      titulo: "Cliente Arquivado",
      mensagem: "O cliente foi movido para os arquivados com sucesso!",
    });

    return { sucesso: true };
  } catch (err) {
    console.error("Erro ao arquivar cliente:", err.message);
    await mostrarAviso(janelaDashboard, {
      tipo: "erro",
      titulo: "Erro ao Arquivar",
      mensagem: "Não foi possível arquivar o cliente. Tente novamente.",
    });
    return { sucesso: false, mensagem: err.message };
  }
});

ipcMain.handle("reativar-cliente-banco", async (event, idCliente) => {
  try {
    if (await negarSemPermissao(janelaDashboard, "clientes_arquivar")) return { sucesso: false };

    const { error } = await supabase
      .from("clientes")
      .update({ ativo: true })
      .eq("id", idCliente);

    if (error) throw error;

    if (janelaDashboard && !janelaDashboard.isDestroyed()) {
      janelaDashboard.webContents.send("clientes-atualizados");
    }

    await mostrarAviso(janelaDashboard, {
      tipo: "sucesso",
      titulo: "Cliente Reativo",
      mensagem: "O cliente voltou a aparecer nas listagens ativas!",
    });

    return { sucesso: true };
  } catch (err) {
    console.error("Erro ao reativar clientes:", err.message);
    await mostrarAviso(janelaDashboard, {
      tipo: "erro",
      titulo: "Erro ao Reativar",
      mensagem: "Não foi possível reativar o cliente. Tente novamente.",
    });
    return { sucesso: false, mensagem: err.message };
  }
});

// ============================= LOCAÇÕES =======================
ipcMain.handle("buscar-locacoes-ativas", async () => {
  try {
    console.log("Buscando locações ativas para a empresa: ${idEmpresaLogada}");

    const { data, error } = await supabase
      .from("locacoes")
      .select(
        `
        id, id_cliente, id_veiculo, data_inicio, data_fim, valor_total, status,
        clientes ( nome ), veiculos ( modelo, placa )
      `,
      )
      .eq("status", "Ativo")
      .eq("id_empresa", idEmpresaLogada)
      .order("created_at", { ascending: false });

    if (error) {
      console.error("Erro ao buscar locações ativas do banco:", error.message);
      throw error;
    }
    return data;
  } catch (err) {
    console.error("Erro fatal ao buscar locações ativas:", err);
    return [];
  }
});

ipcMain.handle("buscar-locacoes-historico", async () => {
  try {
    console.log(
      "Buscando histórico de locações para a empresa: ${idEmpresaLogada}",
    );

    const { data, error } = await supabase
      .from("locacoes")
      .select(
        `
        id, id_cliente, id_veiculo, data_inicio, data_fim, valor_total, status,
        clientes ( nome ), veiculos ( modelo, placa )
      `,
      )
      .eq("status", "Concluído")
      .eq("id_empresa", idEmpresaLogada)
      .order("data_fim", { ascending: false });

    if (error) {
      console.error(
        "Erro ao buscar histórico de locações do banco:",
        error.message,
      );
      throw error;
    }
    return data;
  } catch (err) {
    console.error("Erro fatal ao buscar histórico de locações:", err);
    return [];
  }
});

ipcMain.on("abrir-modal-locacao", (evento) => {
  if (janelaModalLocacao) {
    janelaModalLocacao.focus();
    return;
  }

  const janelaMae = BrowserWindow.fromWebContents(evento.sender);

  janelaModalLocacao = new BrowserWindow({
    width: 480,
    height: 560,
    parent: janelaMae,
    modal: true,
    frame: false,
    resizable: false,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, "../preload/preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  janelaModalLocacao.loadFile(
    path.join(__dirname, "../renderer/modais/locacao/modalLocacao.html"),
  );
  janelaModalLocacao.once("ready-to-show", () => janelaModalLocacao.show());
  janelaModalLocacao.on("closed", () => {
    janelaModalLocacao = null;
  });
});

ipcMain.on("fechar-modal-locacao", () => {
  if (janelaModalLocacao) janelaModalLocacao.close();
});

ipcMain.handle("salvar-locacao-banco", async (event, novaLocacao) => {
  try {
    if (await negarSemPermissao(janelaModalLocacao, "locacoes_gerenciar")) return { sucesso: false };

    const { data: veiculoAtual, error: erroConsultaVeiculo } = await supabase
      .from("veiculos")
      .select("status")
      .eq("id", novaLocacao.id_veiculo)
      .single();

    if (erroConsultaVeiculo || !veiculoAtual) {
      await mostrarAviso(janelaModalLocacao, {
        tipo: "erro",
        titulo: "Veículo Não Encontrado",
        mensagem:
          "Não foi possível confirmar a disponibilidade deste veículo. Atualize a lista e tente novamente.",
      });
      return { sucesso: false };
    }

    if (veiculoAtual.status !== "Disponível") {
      await mostrarAviso(janelaModalLocacao, {
        tipo: "erro",
        titulo: "Veículo Indisponível",
        mensagem: `Este veículo não está mais disponível (status atual: ${veiculoAtual.status}). Atualize a lista e escolha outro veículo.`,
      });
      return { sucesso: false };
    }

    const locacaoComEmpresa = {
      ...novaLocacao,
      id_empresa: idEmpresaLogada,
    };

    const { error: erroLocacao } = await supabase
      .from("locacoes")
      .insert([locacaoComEmpresa]);

    if (erroLocacao) {
      console.error(
        "Erro ao inserir locação no Supabase:",
        erroLocacao.message,
      );
      await mostrarAviso(janelaModalLocacao, {
        tipo: "erro",
        titulo: "Erro na Operação",
        mensagem: `Não foi possível registrar a locação. Motivo: ${erroLocacao.message}`,
      });
      return { sucesso: false, mensagem: erroLocacao.message };
    }

    const { error: erroVeiculo } = await supabase
      .from("veiculos")
      .update({ status: "Alugado" })
      .eq("id", novaLocacao.id_veiculo);

    if (erroVeiculo) {
      console.error(
        "Erro ao mudar status do veículo para Alugado:",
        erroVeiculo.message,
      );
    }

    if (janelaDashboard && !janelaDashboard.isDestroyed()) {
      janelaDashboard.webContents.send("locacoes-atualizadas");
      janelaDashboard.webContents.send("frota-atualizada");
    }

    await mostrarAviso(janelaModalLocacao, {
      tipo: "sucesso",
      titulo: "Sucesso",
      mensagem: "Locação registrada com sucesso! Veículo alugado.",
    });

    return { sucesso: true };
  } catch (err) {
    console.error("Erro interno ao salvar locação:", err);
    return { sucesso: false, mensagem: "Erro interno no servidor." };
  }
});

ipcMain.handle(
  "finalizar-locacao-manual",
  async (event, { idLocacao, idVeiculo }) => {
    try {
      if (await negarSemPermissao(janelaDashboard, "locacoes_gerenciar")) return { sucesso: false };

      const { error: erroLocacao } = await supabase
        .from("locacoes")
        .update({ status: "Concluído" })
        .eq("id", idLocacao);

      if (erroLocacao) throw erroLocacao;

      const { error: erroVeiculo } = await supabase
        .from("veiculos")
        .update({ status: "Disponível" })
        .eq("id", idVeiculo);

      if (erroVeiculo) throw erroVeiculo;

      if (janelaDashboard && !janelaDashboard.isDestroyed()) {
        janelaDashboard.webContents.send("locacoes-atualizadas");
        janelaDashboard.webContents.send("frota-atualizada");
      }

      await mostrarAviso(janelaDashboard, {
        tipo: "sucesso",
        titulo: "Sucesso",
        mensagem: "Locação finalizada e veículo liberado com sucesso!",
      });

      return { sucesso: true };
    } catch (err) {
      console.error("Erro ao finalizar locação manualmente:", err.message);
      return { sucesso: false, mensagem: err.message };
    }
  },
);

// ============================== FINANÇAS =======================
ipcMain.handle("buscar-dados-financeiros", async () => {
  try {
    console.log(
      "Calculando balanço financeiro inteligente para a empresa: ",
      idEmpresaLogada,
    );

    const { data: todasLocacoes, error } = await supabase
      .from("locacoes")
      .select(
        `
        id, data_fim, valor_total, status,
        clientes ( nome ), veiculos ( modelo, placa )
      `,
      )
      .eq("id_empresa", idEmpresaLogada)
      .order("data_fim", { ascending: false });

    if (error) {
      console.error(
        "Erro ao consultar dados para o financeiro:",
        error.message,
      );
      throw error;
    }

    const agora = new Date();
    const mesAtual = agora.getMonth();
    const anoAtual = agora.getFullYear();

    // Data do mês passado
    const dataMesPassado = new Date(anoAtual, mesAtual - 1, 1);
    const mesPassado = dataMesPassado.getMonth();
    const anoMesPassado = dataMesPassado.getFullYear();

    let faturamentoTotalMesAtual = 0;
    let faturamentoTotalMesAnterior = 0;
    let recebimentoProjetado = 0;
    let totalContratosConcluidos = 0;
    let fluxoCaixaEntradas = [];

    if (todasLocacoes && todasLocacoes.length > 0) {
      todasLocacoes.forEach((loc) => {
        const valor = parseFloat(loc.valor_total) || 0;

        if (loc.status === "Concluído") {
          totalContratosConcluidos++;
          fluxoCaixaEntradas.push(loc);

          if (loc.data_fim) {
            const dataFimContrato = new Date(loc.data_fim);
            const mContrato = dataFimContrato.getMonth();
            const aContrato = dataFimContrato.getFullYear();

            if (mContrato === mesAtual && aContrato === anoAtual) {
              faturamentoTotalMesAtual += valor;
            } else if (
              mContrato === mesPassado &&
              aContrato === anoMesPassado
            ) {
              faturamentoTotalMesAnterior += valor;
            }
          }
        } else if (loc.status === "Ativo") {
          recebimentoProjetado += valor;
        }
      });
    }

    let variacaoPercentual = 0;
    if (faturamentoTotalMesAnterior > 0) {
      variacaoPercentual =
        ((faturamentoTotalMesAtual - faturamentoTotalMesAnterior) /
          faturamentoTotalMesAnterior) *
        100;
    } else if (
      faturamentoTotalMesAnterior === 0 &&
      faturamentoTotalMesAtual > 0
    ) {
      variacaoPercentual = 100;
    }

    const ticketMedio =
      totalContratosConcluidos > 0
        ? faturamentoTotalMesAtual / totalContratosConcluidos
        : 0;

    return {
      sucesso: true,
      indicadores: {
        faturamentoTotal: faturamentoTotalMesAtual,
        recebimentoProjetado,
        ticketMedio,
        variacaoPercentual: parseFloat(variacaoPercentual.toFixed(1)),
      },
      fluxoCaixa: fluxoCaixaEntradas,
    };
  } catch (err) {
    console.error("Erro fatal no motor financeiro:", err.message);
    return { sucesso: false, mensagem: err.message };
  }
});


// =========================== GRUPOS DE PERMISSÃO ======================
ipcMain.on('abrir-modal-grupo', (evento) => {
  if (janelaModalGrupoPermissao) {
    janelaModalGrupoPermissao.focus();
    return;
  }

  const janelaMae = BrowserWindow.fromWebContents(evento.sender);

  janelaModalGrupoPermissao = new BrowserWindow({
    width: 560,
    height: 660,
    parent: janelaMae,
    modal: true,
    frame: false,
    resizable: false,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, '../preload/preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  janelaModalGrupoPermissao.loadFile(path.join(__dirname, '../renderer/modais/grupo-permissao/modalGrupoPermissao.html'));
  janelaModalGrupoPermissao.once('ready-to-show', () => janelaModalGrupoPermissao.show());
  janelaModalGrupoPermissao.on('closed', () => { janelaModalGrupoPermissao = null; });
});

ipcMain.on('fechar-modal-grupo', () => {
  if (janelaModalGrupoPermissao) janelaModalGrupoPermissao.close();
});

ipcMain.handle('buscar-colaboradores', async () => {
  try {
    if (!temPermissao('administracao')) return [];

    const { data, error } = await supabase
      .from('usuarios')
      .select('id, username, nome, email, telefone, ativo, id_grupo_permissao, grupos_permissao ( nome )')
      .eq('id_empresa', String(idEmpresaLogada))
      .eq('cargo', 'Colaborador')
      .eq('ativo', true)
      .order('nome', { ascending: true });

    if (error) {
      console.error('Erro ao buscar colaboradores:', error.message);
      return [];
    }
    return data;
  } catch (err) {
    console.error('Erro inesperado ao buscar colaboradores:', err);
    return [];
  }
});

ipcMain.handle('buscar-colaboradores-arquivados', async () => {
  try {
    if (!temPermissao('administracao')) return [];

    const { data, error } = await supabase
      .from('usuarios')
      .select('id, username, nome, email, telefone, ativo, id_grupo_permissao, grupos_permissao ( nome )')
      .eq('id_empresa', String(idEmpresaLogada))
      .eq('cargo', 'Colaborador')
      .eq('ativo', false)
      .order('nome', { ascending: true });

    if (error) {
      console.error('Erro ao buscar colaboradores arquivados:', error.message);
      return [];
    }
    return data;
  } catch (err) {
    console.error('Erro inesperado ao buscar colaboradores arquivados:', err);
    return [];
  }
});

ipcMain.handle('arquivar-colaborador-banco', async (event, idColaborador) => {
  try {
    if (await negarSemPermissao(janelaDashboard, "administracao")) return { sucesso: false };

    const { error } = await supabase
      .from('usuarios')
      .update({ ativo: false })
      .eq('id', idColaborador);

    if (error) throw error;

    if (janelaDashboard && !janelaDashboard.isDestroyed()) {
      janelaDashboard.webContents.send('colaboradores-atualizados');
    }

    await mostrarAviso(janelaDashboard, {
      tipo: 'sucesso', titulo: 'Colaborador Arquivado',
      mensagem: 'O colaborador foi arquivado e seu acesso ao sistema foi bloqueado.'
    });

    return { sucesso: true };
  } catch (err) {
    console.error('Erro ao arquivar colaborador:', err.message);
    await mostrarAviso(janelaDashboard, {
      tipo: 'erro', titulo: 'Erro ao Arquivar',
      mensagem: 'Não foi possível arquivar o colaborador. Tente novamente.'
    });
    return { sucesso: false, mensagem: err.message };
  }
});

ipcMain.handle('reativar-colaborador-banco', async (event, idColaborador) => {
  try {
    if (await negarSemPermissao(janelaDashboard, "administracao")) return { sucesso: false };

    const { error } = await supabase
      .from('usuarios')
      .update({ ativo: true })
      .eq('id', idColaborador);

    if (error) throw error;

    if (janelaDashboard && !janelaDashboard.isDestroyed()) {
      janelaDashboard.webContents.send('colaboradores-atualizados');
    }

    await mostrarAviso(janelaDashboard, {
      tipo: 'sucesso', titulo: 'Colaborador Reativado',
      mensagem: 'O colaborador voltou a ter acesso ao sistema!'
    });

    return { sucesso: true };
  } catch (err) {
    console.error('Erro ao reativar colaborador:', err.message);
    await mostrarAviso(janelaDashboard, {
      tipo: 'erro', titulo: 'Erro ao Reativar',
      mensagem: 'Não foi possível reativar o colaborador. Tente novamente.'
    });
    return { sucesso: false, mensagem: err.message };
  }
});

// =========================== MODAL DE COLABORADOR (CRIAR / EDITAR) ======================
ipcMain.on('abrir-modal-colaborador', (evento) => {
  if (janelaModalColaborador) {
    janelaModalColaborador.focus();
    return;
  }

  const janelaMae = BrowserWindow.fromWebContents(evento.sender);

  janelaModalColaborador = new BrowserWindow({
    width: 520,
    height: 700,
    parent: janelaMae,
    modal: true,
    frame: false,
    resizable: false,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, '../preload/preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  janelaModalColaborador.loadFile(path.join(__dirname, '../renderer/modais/colaborador/modalColaborador.html'));
  janelaModalColaborador.once('ready-to-show', () => janelaModalColaborador.show());
  janelaModalColaborador.on('closed', () => { janelaModalColaborador = null; });
});

ipcMain.on('fechar-modal-colaborador', () => {
  if (janelaModalColaborador) janelaModalColaborador.close();
});

ipcMain.handle('salvar-colaborador-banco', async (event, dados) => {
  try {
    const editando = !!dados.id;

    if (await negarSemPermissao(janelaModalColaborador, editando ? 'administracao' : 'administracao')) {
      return { sucesso: false };
    }

    const nome = (dados.nome || '').trim();
    const username = (dados.username || '').trim();
    const email = (dados.email || '').trim();
    const telefone = (dados.telefone || '').trim();

    if (!nome) {
      await mostrarAviso(janelaModalColaborador, {
        tipo: 'erro', titulo: 'Nome Obrigatório',
        mensagem: 'Por favor, informe o nome completo do colaborador.'
      });
      return { sucesso: false };
    }

    if (!username) {
      await mostrarAviso(janelaModalColaborador, {
        tipo: 'erro', titulo: 'Usuário Obrigatório',
        mensagem: 'Por favor, informe um nome de usuário para o colaborador.'
      });
      return { sucesso: false };
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (email && !emailRegex.test(email)) {
      await mostrarAviso(janelaModalColaborador, {
        tipo: 'erro', titulo: 'E-mail Inválido',
        mensagem: 'Por favor, informe um e-mail válido (exemplo@empresa.com) ou deixe o campo em branco.'
      });
      return { sucesso: false };
    }

    if (!dados.id_grupo_permissao) {
      await mostrarAviso(janelaModalColaborador, {
        tipo: 'erro', titulo: 'Grupo Obrigatório',
        mensagem: 'Todo colaborador precisa pertencer a um grupo de permissão. Selecione um grupo existente ou crie um novo.'
      });
      return { sucesso: false };
    }

    if (!editando) {
      if (!dados.senha || dados.senha.length < 6) {
        await mostrarAviso(janelaModalColaborador, {
          tipo: 'erro', titulo: 'Senha Inválida',
          mensagem: 'A senha deve conter pelo menos 6 caracteres.'
        });
        return { sucesso: false };
      }

      if (dados.senha !== dados.confirmarSenha) {
        await mostrarAviso(janelaModalColaborador, {
          tipo: 'erro', titulo: 'Senhas Diferentes',
          mensagem: 'As senhas não coincidem. Verifique e tente novamente.'
        });
        return { sucesso: false };
      }
    }

    // O grupo escolhido precisa existir e pertencer a esta empresa
    const { data: grupoValido, error: erroGrupo } = await supabase
      .from('grupos_permissao')
      .select('id')
      .eq('id', dados.id_grupo_permissao)
      .eq('id_empresa', String(idEmpresaLogada))
      .limit(1);

    if (erroGrupo || !grupoValido || grupoValido.length === 0) {
      await mostrarAviso(janelaModalColaborador, {
        tipo: 'erro', titulo: 'Grupo Inválido',
        mensagem: 'O grupo selecionado não foi encontrado. Atualize a lista e escolha outro grupo.'
      });
      return { sucesso: false };
    }

    // Usuário e e-mail precisam ser únicos em todo o sistema (o login procura em toda a tabela)
    let consultaUsername = supabase.from('usuarios').select('id').eq('username', username);
    if (editando) consultaUsername = consultaUsername.neq('id', dados.id);
    const { data: usernameExistente, error: erroUsername } = await consultaUsername;

    if (erroUsername) {
      console.error('Erro ao verificar username:', erroUsername.message);
      await mostrarAviso(janelaModalColaborador, {
        tipo: 'erro', titulo: 'Erro na Verificação',
        mensagem: 'Não foi possível validar os dados. Tente novamente.'
      });
      return { sucesso: false };
    }

    if (usernameExistente && usernameExistente.length > 0) {
      await mostrarAviso(janelaModalColaborador, {
        tipo: 'erro', titulo: 'Usuário já Existe',
        mensagem: 'Este nome de usuário já está sendo utilizado. Escolha outro.'
      });
      return { sucesso: false };
    }

    if (email) {
      let consultaEmail = supabase.from('usuarios').select('id').eq('email', email);
      if (editando) consultaEmail = consultaEmail.neq('id', dados.id);
      const { data: emailExistente, error: erroEmail } = await consultaEmail;

      if (erroEmail) {
        console.error('Erro ao verificar e-mail:', erroEmail.message);
        await mostrarAviso(janelaModalColaborador, {
          tipo: 'erro', titulo: 'Erro na Verificação',
          mensagem: 'Não foi possível validar os dados. Tente novamente.'
        });
        return { sucesso: false };
      }

      if (emailExistente && emailExistente.length > 0) {
        await mostrarAviso(janelaModalColaborador, {
          tipo: 'erro', titulo: 'E-mail já Existe',
          mensagem: 'Este e-mail já está sendo utilizado. Informe outro.'
        });
        return { sucesso: false };
      }
    }

    let erroSalvar;

    if (editando) {
      const { error } = await supabase
        .from('usuarios')
        .update({
          nome,
          username,
          email: email || null,
          telefone: telefone || null,
          id_grupo_permissao: Number(dados.id_grupo_permissao)
        })
        .eq('id', dados.id)
        .eq('id_empresa', idEmpresaLogada)
        .eq('cargo', 'Colaborador');
      erroSalvar = error;
    } else {
      const senhaHash = await bcrypt.hash(dados.senha, 10);

      const { error } = await supabase
        .from('usuarios')
        .insert([{
          nome,
          username,
          email: email || null,
          telefone: telefone || null,
          senha: senhaHash,
          id_empresa: idEmpresaLogada,
          cargo: 'Colaborador',
          id_grupo_permissao: Number(dados.id_grupo_permissao),
          ativo: true
        }]);
      erroSalvar = error;
    }

    if (erroSalvar) {
      console.error('Erro ao salvar colaborador:', erroSalvar.message);
      await mostrarAviso(janelaModalColaborador, {
        tipo: 'erro', titulo: 'Erro na Operação',
        mensagem: `Não foi possível salvar os dados do colaborador. Motivo: ${erroSalvar.message}`
      });
      return { sucesso: false, mensagem: erroSalvar.message };
    }

    if (janelaDashboard && !janelaDashboard.isDestroyed()) {
      janelaDashboard.webContents.send('colaboradores-atualizados');
      janelaDashboard.webContents.send('grupos-atualizados');
    }

    await mostrarAviso(janelaModalColaborador, {
      tipo: 'sucesso', titulo: 'Sucesso',
      mensagem: editando
        ? `O cadastro de ${nome} foi atualizado com sucesso!`
        : `O colaborador ${nome} foi cadastrado com sucesso!`
    });

    return { sucesso: true };
  } catch (err) {
    console.error('Erro interno ao salvar colaborador:', err);
    return { sucesso: false, mensagem: 'Erro interno no servidor.' };
  }
});

// =========================== REDEFINIR SENHA DE COLABORADOR ======================
ipcMain.on('abrir-modal-redefinir-senha-colaborador', (evento) => {
  if (janelaModalRedefinirSenhaColaborador) {
    janelaModalRedefinirSenhaColaborador.focus();
    return;
  }

  const janelaMae = BrowserWindow.fromWebContents(evento.sender);

  janelaModalRedefinirSenhaColaborador = new BrowserWindow({
    width: 420,
    height: 440,
    parent: janelaMae,
    modal: true,
    frame: false,
    resizable: false,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, '../preload/preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  janelaModalRedefinirSenhaColaborador.loadFile(path.join(__dirname, '../renderer/modais/redefinir-senha-colaborador/modalRedefinirSenhaColaborador.html'));
  janelaModalRedefinirSenhaColaborador.once('ready-to-show', () => janelaModalRedefinirSenhaColaborador.show());
  janelaModalRedefinirSenhaColaborador.on('closed', () => { janelaModalRedefinirSenhaColaborador = null; });
});

ipcMain.on('fechar-modal-redefinir-senha-colaborador', () => {
  if (janelaModalRedefinirSenhaColaborador) janelaModalRedefinirSenhaColaborador.close();
});

ipcMain.handle('redefinir-senha-colaborador', async (event, { idColaborador, novaSenha, confirmarSenha }) => {
  try {
    if (await negarSemPermissao(janelaModalRedefinirSenhaColaborador, 'administracao')) {
      return { sucesso: false };
    }

    if (!novaSenha || novaSenha.length < 6) {
      await mostrarAviso(janelaModalRedefinirSenhaColaborador, {
        tipo: 'erro', titulo: 'Senha Inválida',
        mensagem: 'A nova senha deve conter pelo menos 6 caracteres.'
      });
      return { sucesso: false };
    }

    if (novaSenha !== confirmarSenha) {
      await mostrarAviso(janelaModalRedefinirSenhaColaborador, {
        tipo: 'erro', titulo: 'Senhas Diferentes',
        mensagem: 'As senhas não coincidem. Verifique e tente novamente.'
      });
      return { sucesso: false };
    }

    const novaSenhaHash = await bcrypt.hash(novaSenha, 10);

    const { data: atualizado, error } = await supabase
      .from('usuarios')
      .update({ senha: novaSenhaHash })
      .eq('id', idColaborador)
      .eq('id_empresa', idEmpresaLogada)
      .eq('cargo', 'Colaborador')
      .select('id');

    if (error || !atualizado || atualizado.length === 0) {
      console.error('Erro ao redefinir senha do colaborador:', error?.message);
      await mostrarAviso(janelaModalRedefinirSenhaColaborador, {
        tipo: 'erro', titulo: 'Erro ao Redefinir',
        mensagem: 'Não foi possível redefinir a senha deste colaborador. Tente novamente.'
      });
      return { sucesso: false };
    }

    await mostrarAviso(janelaModalRedefinirSenhaColaborador, {
      tipo: 'sucesso', titulo: 'Senha Redefinida',
      mensagem: 'A senha do colaborador foi redefinida com sucesso! Ele já pode entrar com a nova senha.'
    });

    return { sucesso: true };
  } catch (err) {
    console.error('Erro inesperado ao redefinir senha do colaborador:', err);
    return { sucesso: false };
  }
});

// =========================== VER COLABORADORES DO GRUPO (E MOVER) ======================
