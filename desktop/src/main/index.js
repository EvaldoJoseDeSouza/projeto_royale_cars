const { app, BrowserWindow, ipcMain, Menu, Tray, dialog, clipboard } = require("electron");
const path = require("path");

const supabase = require("./supabase");
const { sessao, temPermissao, limparSessao } = require("./sessao");
const { registrarIpcSessao } = require("./ipc/sessao");
const { registrarIpcModelos } = require("./ipc/modelos");
const { registrarIpcColaboradores } = require("./ipc/colaboradores");
const { registrarIpcClientes } = require("./ipc/clientes");
const { registrarIpcFrota } = require("./ipc/frota");
const { registrarIpcLocacoes } = require("./ipc/locacoes");
const { registrarIpcContratos } = require("./ipc/contratos");
const { registrarIpcPainel } = require("./ipc/painel");
const { registrarIpcManutencoes } = require("./ipc/manutencoes");

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
let janelaModalGrupoPermissao;
let janelaModalColaborador;
let janelaModalSenhaTemporaria;

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

  if (!sessao.usuario || sessao.usuario.trocar_senha) return;

  // Já está aberto (o aviso chegou duas vezes): só mostra
  if (janelaDashboard && !janelaDashboard.isDestroyed()) {
    janelaDashboard.show();
    return;
  }

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

  if (janelaPrincipal && !janelaPrincipal.isDestroyed()) {
    janelaPrincipal.removeAllListeners("close");
    janelaPrincipal.close();
  }
});

// Sem esta marca, o dashboard só se escondia na bandeja e o programa não fechava
app.on("before-quit", () => {
  app.isQuitting = true;
});

// Botão "Sair": encerra o login e fecha o programa
ipcMain.on("fechar", async () => {
  app.isQuitting = true;
  try {
    await supabase.auth.signOut();
  } catch (erro) {
    console.error("Erro ao sair do Supabase:", erro);
  }
  limparSessao();
  app.quit();
});

// ===================== SAÍDA POR INATIVIDADE ====================
ipcMain.on("sair-por-inatividade", async () => {
  await supabase.auth.signOut();
  limparSessao();
  criarJanela();
  const janelaLogin = janelaPrincipal;
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
// Cada aviso guarda a sua própria resposta, pelo número da janela.
// Antes era uma variável só: com dois avisos abertos, um deles travava.
const confirmacoesAbertas = new Map();

function abrirJanelaConfirmacao(janelaMae, dadosConfimacao) {
  return new Promise((resolve) => {
    const janelaModalConfirmacao = new BrowserWindow({
      width: 420,
      height: 370,
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

    const idJanela = janelaModalConfirmacao.webContents.id;
    confirmacoesAbertas.set(idJanela, { janela: janelaModalConfirmacao, responder: resolve });

    // Fechou sem responder: conta como "não"
    janelaModalConfirmacao.on("closed", () => {
      const pendente = confirmacoesAbertas.get(idJanela);
      confirmacoesAbertas.delete(idJanela);
      if (pendente) pendente.responder(false);
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

// Responde e fecha só a janela que foi clicada
ipcMain.on("responder-confirmacao", (evento, resposta) => {
  const pendente = confirmacoesAbertas.get(evento.sender.id);
  if (!pendente) return;
  confirmacoesAbertas.delete(evento.sender.id);
  pendente.responder(resposta);
  if (!pendente.janela.isDestroyed()) pendente.janela.close();
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
ipcMain.on("abrir-modal-veiculo", (evento) => {
  if (janelaModalVeiculo) {
    janelaModalVeiculo.focus();
    return;
  }

  const janelaMae = BrowserWindow.fromWebContents(evento.sender);

  janelaModalVeiculo = new BrowserWindow({
    width: 520,
    height: 530,
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

registrarIpcFrota({
  mostrarAviso,
  obterJanelaDashboard: () => janelaDashboard,
  obterJanelaVeiculo: () => janelaModalVeiculo,
});


// =============== CLIENTES ===================
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
function criarJanelaModal(janelaMae, arquivoHtml, largura, altura) {
  const janela = new BrowserWindow({
    width: largura,
    height: altura,
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
  janela.loadFile(path.join(__dirname, "../renderer/modais", arquivoHtml));
  janela.once("ready-to-show", () => janela.show());
  return janela;
}

let janelaModalDevolucao;
let janelaModalCancelamento;

ipcMain.on("abrir-modal-locacao", (evento) => {
  if (janelaModalLocacao) return janelaModalLocacao.focus();
  janelaModalLocacao = criarJanelaModal(BrowserWindow.fromWebContents(evento.sender), "locacao/modalLocacao.html", 560, 620);
  janelaModalLocacao.on("closed", () => { janelaModalLocacao = null; });
});

ipcMain.on("fechar-modal-locacao", () => {
  if (janelaModalLocacao) janelaModalLocacao.close();
});

ipcMain.on("abrir-modal-devolucao", (evento) => {
  if (janelaModalDevolucao) return janelaModalDevolucao.focus();
  janelaModalDevolucao = criarJanelaModal(BrowserWindow.fromWebContents(evento.sender), "devolucao/modalDevolucao.html", 600, 720);
  janelaModalDevolucao.on("closed", () => { janelaModalDevolucao = null; });
});

ipcMain.on("fechar-modal-devolucao", () => {
  if (janelaModalDevolucao) janelaModalDevolucao.close();
});

ipcMain.on("abrir-modal-cancelar-locacao", (evento) => {
  if (janelaModalCancelamento) return janelaModalCancelamento.focus();
  janelaModalCancelamento = criarJanelaModal(BrowserWindow.fromWebContents(evento.sender), "cancelar-locacao/modalCancelarLocacao.html", 460, 360);
  janelaModalCancelamento.on("closed", () => { janelaModalCancelamento = null; });
});

ipcMain.on("fechar-modal-cancelar-locacao", () => {
  if (janelaModalCancelamento) janelaModalCancelamento.close();
});
let janelaModalContrato;

ipcMain.on("abrir-modal-contrato", (evento) => {
  if (janelaModalContrato) return janelaModalContrato.focus();
  janelaModalContrato = criarJanelaModal(BrowserWindow.fromWebContents(evento.sender), "contrato/modalContrato.html", 800, 720);
  janelaModalContrato.on("closed", () => { janelaModalContrato = null; });
});

ipcMain.on("fechar-modal-contrato", () => {
  if (janelaModalContrato) janelaModalContrato.close();
});

registrarIpcContratos({ mostrarAviso });

registrarIpcLocacoes({
  mostrarAviso,
  obterJanelaDashboard: () => janelaDashboard,
  obterJanelaLocacao: () => janelaModalLocacao,
  obterJanelaDevolucao: () => janelaModalDevolucao,
  obterJanelaCancelamento: () => janelaModalCancelamento,
});

// ============================== MANUTENÇÃO ==============================
let janelaModalManutencao;
let janelaModalLiberarManutencao;

ipcMain.on("abrir-modal-manutencao", (evento) => {
  if (janelaModalManutencao) return janelaModalManutencao.focus();
  janelaModalManutencao = criarJanelaModal(BrowserWindow.fromWebContents(evento.sender), "manutencao/modalManutencao.html", 560, 700);
  janelaModalManutencao.on("closed", () => { janelaModalManutencao = null; });
});

ipcMain.on("fechar-modal-manutencao", () => {
  if (janelaModalManutencao) janelaModalManutencao.close();
});

ipcMain.on("abrir-modal-liberar-manutencao", (evento) => {
  if (janelaModalLiberarManutencao) return janelaModalLiberarManutencao.focus();
  janelaModalLiberarManutencao = criarJanelaModal(
    BrowserWindow.fromWebContents(evento.sender), "liberar-manutencao/modalLiberarManutencao.html", 520, 560);
  janelaModalLiberarManutencao.on("closed", () => { janelaModalLiberarManutencao = null; });
});

ipcMain.on("fechar-modal-liberar-manutencao", () => {
  if (janelaModalLiberarManutencao) janelaModalLiberarManutencao.close();
});

registrarIpcManutencoes({
  mostrarAviso,
  obterJanelaEnviar: () => janelaModalManutencao,
  obterJanelaLiberar: () => janelaModalLiberarManutencao,
});

// ============================== PAINEL E FINANÇAS =======================
registrarIpcPainel();

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
  senhaTemporariaParaMostrar = null; 
  return dados;
});

ipcMain.on("fechar-modal-senha-temporaria", () => {
  if (janelaModalSenhaTemporaria) janelaModalSenhaTemporaria.close();
});

ipcMain.on("copiar-texto", (evento, texto) => {
  clipboard.writeText(String(texto || ""));
});

// =========================== COLABORADORES ======================
registrarIpcColaboradores({
  mostrarAviso,
  obterJanelaDashboard: () => janelaDashboard,
  obterJanelaColaborador: () => janelaModalColaborador,
  mostrarSenhaTemporaria,
});
