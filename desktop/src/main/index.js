const { app, BrowserWindow, ipcMain, Menu, Tray, dialog, clipboard } = require("electron");
const path = require("path");

// Conexão com o banco, sessão e conversas (IPC) do login ficam em arquivos próprios
const supabase = require("./supabase");
const { sessao, temPermissao, limparSessao } = require("./sessao");
const { registrarIpcSessao } = require("./ipc/sessao");
const { registrarIpcModelos } = require("./ipc/modelos");
const { registrarIpcColaboradores } = require("./ipc/colaboradores");
const { registrarIpcClientes } = require("./ipc/clientes");

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
let janelaModalSenhaTemporaria;

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
  obterJanelaDashboard: () => janelaDashboard,
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

  // Se a pessoa entrou com senha temporária, o modal abre no modo
  // obrigatório. Quem decide é o processo principal (ele sabe o que o banco
  // disse), e não a tela: assim ninguém consegue "pular" a troca.
  const obrigatoria = Boolean(sessao.usuario && sessao.usuario.trocar_senha);
  janelaModalTrocarSenha.loadFile(
    path.join(__dirname, "../renderer/modais/trocar-senha/modalTrocarSenha.html"),
    { query: { obrigatoria: obrigatoria ? "1" : "0" } },
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
  // Trava de segurança: só abre o sistema para quem está logado e já
  // criou a própria senha (não dá para pular a troca obrigatória).
  if (!sessao.usuario || sessao.usuario.trocar_senha) return;

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

// ===================== SAÍDA POR INATIVIDADE ====================
// O dashboard conta o tempo sem uso (mouse e teclado). Passou do limite,
// ele pede para sair: encerramos o login, fechamos o sistema e voltamos
// para a tela de login. Igual à web, que sai depois de 30 minutos parada.
ipcMain.on("sair-por-inatividade", async () => {
  await supabase.auth.signOut();
  limparSessao();

  // A ordem importa: PRIMEIRO abrimos o login, DEPOIS fechamos o resto.
  // Se fechássemos tudo antes, por um instante não haveria nenhuma janela
  // e o Electron encerraria o programa (evento "window-all-closed").
  criarJanela();
  const janelaLogin = janelaPrincipal;

  // Fecha o dashboard e qualquer modal aberto. O dashboard normalmente só
  // se esconde ao fechar (bandeja); destroy() fecha de verdade.
  BrowserWindow.getAllWindows().forEach((janela) => {
    if (janela !== janelaLogin && !janela.isDestroyed()) janela.destroy();
  });
  janelaDashboard = null;

  janelaLogin.webContents.once("did-finish-load", () => {
    mostrarAviso(janelaLogin, {
      tipo: "erro",
      titulo: "Sessão encerrada",
      mensagem: "Você ficou muito tempo sem usar o sistema. Entre de novo para continuar.",
    });
  });
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
// Listar, salvar, arquivar e reativar ficam em main/ipc/clientes.js.
// Aqui ficam só a abertura e o fechamento do modal.
ipcMain.on("abrir-modal-cliente", (evento) => {
  if (janelaModalCliente) {
    janelaModalCliente.focus();
    return;
  }

  const janelaMae = BrowserWindow.fromWebContents(evento.sender);

  janelaModalCliente = new BrowserWindow({
    width: 520,
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

registrarIpcClientes({
  mostrarAviso,
  obterJanelaDashboard: () => janelaDashboard,
  obterJanelaCliente: () => janelaModalCliente,
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

// =========================== MODAL DE COLABORADOR (CRIAR / EDITAR) ======================
ipcMain.on('abrir-modal-colaborador', (evento) => {
  if (janelaModalColaborador) {
    janelaModalColaborador.focus();
    return;
  }

  const janelaMae = BrowserWindow.fromWebContents(evento.sender);

  janelaModalColaborador = new BrowserWindow({
    width: 560,
    height: 760,
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

// =========================== SENHA TEMPORÁRIA ======================
// Janela que mostra a senha gerada ao cadastrar alguém ou redefinir a
// senha. A senha fica guardada aqui só até a janela pedir; depois de
// entregue, é apagada da memória (ela aparece uma única vez).
let senhaTemporariaParaMostrar = null;

function mostrarSenhaTemporaria(dados) {
  senhaTemporariaParaMostrar = dados;
  if (janelaModalSenhaTemporaria) janelaModalSenhaTemporaria.close();

  janelaModalSenhaTemporaria = new BrowserWindow({
    width: 440,
    height: 390,
    parent: janelaDashboard,
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

  janelaModalSenhaTemporaria.loadFile(
    path.join(__dirname, "../renderer/modais/senha-temporaria/modalSenhaTemporaria.html"),
  );
  janelaModalSenhaTemporaria.once("ready-to-show", () => janelaModalSenhaTemporaria.show());
  janelaModalSenhaTemporaria.on("closed", () => {
    janelaModalSenhaTemporaria = null;
    senhaTemporariaParaMostrar = null;
  });
}

ipcMain.handle("pedir-senha-temporaria", () => {
  const dados = senhaTemporariaParaMostrar;
  senhaTemporariaParaMostrar = null; // entregou, apagou
  return dados;
});

ipcMain.on("fechar-modal-senha-temporaria", () => {
  if (janelaModalSenhaTemporaria) janelaModalSenhaTemporaria.close();
});

// O botão "Copiar" da janela da senha. Quem mexe na área de transferência
// do Windows é o processo principal (a tela não tem acesso direto a ela).
ipcMain.on("copiar-texto", (evento, texto) => {
  clipboard.writeText(String(texto || ""));
});

// =========================== COLABORADORES ======================
// Listar, cadastrar, editar, redefinir senha, desativar e ativar:
// tudo em main/ipc/colaboradores.js.
registrarIpcColaboradores({
  mostrarAviso,
  obterJanelaDashboard: () => janelaDashboard,
  obterJanelaColaborador: () => janelaModalColaborador,
  mostrarSenhaTemporaria,
});
