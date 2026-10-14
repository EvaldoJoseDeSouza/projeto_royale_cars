const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('apiAcesso', {

    // ============================ LOGIN ============================
    enviarLogin: (login, senha) => ipcRenderer.invoke('realizar-login', { login, senha }),
    mudarDeTela: () => ipcRenderer.send('login-sucesso'),
    fecharApp: () => ipcRenderer.send('fechar'),
    pedirUsuarioLogado: () => ipcRenderer.invoke('pedir-usuario-logado'),

    // ========================== FROTA ==============================
    pedirFrota: () => ipcRenderer.invoke('buscar-frota'),
    pedirFrotaArquivada: () => ipcRenderer.invoke('buscar-frota-arquivada'),
    abrirModalCadastro: () => ipcRenderer.send('abrir-modal-veiculo'),
    fecharModalCadastro: () => ipcRenderer.send('fechar-modal-veiculo'),
    salvarVeiculo: (dados) => ipcRenderer.invoke('salvar-veiculo', dados),
    arquivarVeiculo: (idVeiculo) => ipcRenderer.invoke('arquivar-veiculo', idVeiculo),
    reativarVeiculo: (idVeiculo) => ipcRenderer.invoke('reativar-veiculo', idVeiculo),
    aoAtualizarFrota: (funcao) => ipcRenderer.on('frota-atualizada', (event, ...args) => funcao(...args)),

    // ======================== CLIENTE ===============================
    pedirClientes: () => ipcRenderer.invoke('buscar-clientes'),
    pedirClientesArquivados: () => ipcRenderer.invoke('buscar-clientes-arquivados'),
    abrirModalCliente: () => ipcRenderer.send('abrir-modal-cliente'),
    fecharModalCliente: () => ipcRenderer.send('fechar-modal-cliente'),
    salvarCliente: (dados) => ipcRenderer.invoke('salvar-cliente', dados),
    arquivarCliente: (idCliente) => ipcRenderer.invoke('arquivar-cliente', idCliente),
    reativarCliente: (idCliente) => ipcRenderer.invoke('reativar-cliente', idCliente),
    aoAtualizarClientes: (funcao) => ipcRenderer.on('clientes-atualizados', (event, ...args) => funcao(...args)),

    // =========================== LOCAÇÃO =============================
    pedirLocacoesAtivas: () => ipcRenderer.invoke('buscar-locacoes-ativas'),
    pedirLocacoesHistorico: () => ipcRenderer.invoke('buscar-locacoes-historico'),
    abrirModalLocacao: () => ipcRenderer.send('abrir-modal-locacao'),
    fecharModalLocacao: () => ipcRenderer.send('fechar-modal-locacao'),
    salvarLocacaoBanco: (novaLocacao) => ipcRenderer.invoke('salvar-locacao-banco', novaLocacao),
    aoAtualizarLocacoes: (funcaoCallback) => ipcRenderer.on('locacoes-atualizadas', () => funcaoCallback()),
    finalizarLocacao: (idLocacao, idVeiculo) => ipcRenderer.invoke('finalizar-locacao-manual', { idLocacao, idVeiculo }),

    // ============================ FINANÇAS ============================
    pedirDadosFinanceiros: () => ipcRenderer.invoke('buscar-dados-financeiros'),

    // =======================  MODAL DE CONFIRMAÇÃO ====================
    confirmar: (dados) => ipcRenderer.invoke('abrir-modal-confirmacao', dados),
    aoReceberDadosConfirmacao: (funcao) => ipcRenderer.on('dados-confirmacao', (evento, dados) => funcao(dados)),
    responderConfirmacao: (resposta) => ipcRenderer.send('responder-confirmacao', resposta),

    // ============================  TROCA DE SENHA ======================
    abrirModalTrocarSenha: () => ipcRenderer.send('abrir-modal-trocar-senha'),
    fecharModalTrocarSenha: () => ipcRenderer.send('fechar-modal-trocar-senha'),
    trocarSenhaLogado: (dados) => ipcRenderer.invoke('trocar-senha-logado', dados),
    trocarSenhaObrigatoria: (dados) => ipcRenderer.invoke('trocar-senha-obrigatoria', dados),
    aoTrocarSenhaObrigatoria: (funcao) => ipcRenderer.on('senha-obrigatoria-trocada', () => funcao()),

    // ============================  MINHA CONTA E SESSÃO ======================
    salvarMinhaConta: (dados) => ipcRenderer.invoke('salvar-minha-conta', dados),
    sairPorInatividade: () => ipcRenderer.send('sair-por-inatividade'),

    // ==================== MODELOS DE PERMISSÃO (antigos grupos) ====================
    pedirGruposPermissao: () => ipcRenderer.invoke('buscar-grupos-permissao'),
    excluirGrupoPermissao: (idGrupo) => ipcRenderer.invoke('excluir-grupo-permissao', idGrupo),
    aoAtualizarGrupos: (funcao) => ipcRenderer.on('grupos-atualizados', (event, ...args) => funcao(...args)),
    abrirModalGrupo: () => ipcRenderer.send('abrir-modal-grupo'),
    fecharModalGrupo: () => ipcRenderer.send('fechar-modal-grupo'),
    salvarGrupoPermissao: (dados) => ipcRenderer.invoke('salvar-grupo-permissao', dados),

    // ==================== COLABORADORES (só o chefe) ====================
    pedirColaboradores: () => ipcRenderer.invoke('buscar-colaboradores'),
    pedirColaboradoresDesativados: () => ipcRenderer.invoke('buscar-colaboradores-desativados'),
    desativarColaborador: (pessoa) => ipcRenderer.invoke('desativar-colaborador', pessoa),
    ativarColaborador: (pessoa) => ipcRenderer.invoke('ativar-colaborador', pessoa),
    redefinirSenhaColaborador: (pessoa) => ipcRenderer.invoke('redefinir-senha-colaborador', pessoa),
    aoAtualizarColaboradores: (funcao) => ipcRenderer.on('colaboradores-atualizados', (event, ...args) => funcao(...args)),
    abrirModalColaborador: () => ipcRenderer.send('abrir-modal-colaborador'),
    fecharModalColaborador: () => ipcRenderer.send('fechar-modal-colaborador'),
    salvarColaborador: (dados) => ipcRenderer.invoke('salvar-colaborador', dados),

    // ==================== SENHA TEMPORÁRIA ====================
    pedirSenhaTemporaria: () => ipcRenderer.invoke('pedir-senha-temporaria'),
    fecharModalSenhaTemporaria: () => ipcRenderer.send('fechar-modal-senha-temporaria'),
    copiarTexto: (texto) => ipcRenderer.send('copiar-texto', texto),
});