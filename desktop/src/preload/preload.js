const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('apiAcesso', {

    // ============================ LOGIN ============================
    enviarLogin: (login, senha) => ipcRenderer.invoke('realizar-login', { login, senha }),
    criarNovaConta: (dados) => ipcRenderer.invoke('criar-nova-conta', dados),
    mudarDeTela: () => ipcRenderer.send('login-sucesso'),
    fecharApp: () => ipcRenderer.send('fechar'),
    pedirUsuarioLogado: () => ipcRenderer.invoke('pedir-usuario-logado'),

    // ========================== FROTA ==============================
    pedirFrota: () => ipcRenderer.invoke('buscar-frota'),
    pedirFrotaArquivada: () => ipcRenderer.invoke('buscar-frota-arquivada'),
    abrirModalCadastro: () => ipcRenderer.send('abrir-modal-veiculo'),
    fecharModalCadastro: () => ipcRenderer.send('fechar-modal-veiculo'),
    salvarVeiculo: (dados) => ipcRenderer.invoke('salvar-veiculo-banco', dados),
    arquivarVeiculo: (idVeiculo) => ipcRenderer.invoke('arquivar-veiculo-banco', idVeiculo),
    reativarVeiculo: (idVeiculo) => ipcRenderer.invoke('reativar-veiculo-banco', idVeiculo),
    aoAtualizarFrota: (funcao) => ipcRenderer.on('frota-atualizada', (event, ...args) => funcao(...args)),

    // ======================== CLIENTE ===============================
    pedirClientes: () => ipcRenderer.invoke('buscar-clientes'),
    pedirClientesArquivados: () => ipcRenderer.invoke('buscar-clientes-arquivados'),
    abrirModalCliente: () => ipcRenderer.send('abrir-modal-cliente'),
    fecharModalCliente: () => ipcRenderer.send('fechar-modal-cliente'),
    salvarCliente: (dados) => ipcRenderer.invoke('salvar-cliente-banco', dados),
    arquivarCliente: (idCliente) => ipcRenderer.invoke('arquivar-cliente-banco', idCliente),
    reativarCliente: (idCliente) => ipcRenderer.invoke('reativar-cliente-banco', idCliente),
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

    // ============================  RECUPERAÇÃO E TROCA DE SENHA ======================
    verificarEmailExiste: (email) => ipcRenderer.invoke('verificar-email-existe', email),
    redefinirSenhaEsqueci: (dados) => ipcRenderer.invoke('redefinir-senha-esqueci', dados),
    abrirModalTrocarSenha: () => ipcRenderer.send('abrir-modal-trocar-senha'),
    fecharModalTrocarSenha: () => ipcRenderer.send('fechar-modal-trocar-senha'),
    trocarSenhaLogado: (dados) => ipcRenderer.invoke('trocar-senha-logado', dados),

    // ==================== GRUPOS DE PERMISSÃO ====================
    pedirGruposPermissao: () => ipcRenderer.invoke('buscar-grupos-permissao'),
    excluirGrupoPermissao: (idGrupo) => ipcRenderer.invoke('excluir-grupo-permissao', idGrupo),
    aoAtualizarGrupos: (funcao) => ipcRenderer.on('grupos-atualizados', (event, ...args) => funcao(...args)),
    abrirModalGrupo: () => ipcRenderer.send('abrir-modal-grupo'),
    fecharModalGrupo: () => ipcRenderer.send('fechar-modal-grupo'),
    salvarGrupoPermissao: (dados) => ipcRenderer.invoke('salvar-grupo-permissao', dados),

    // ==================== COLABORADORES ====================
    pedirColaboradores: () => ipcRenderer.invoke('buscar-colaboradores'),
    pedirColaboradoresArquivados: () => ipcRenderer.invoke('buscar-colaboradores-arquivados'),
    arquivarColaborador: (id) => ipcRenderer.invoke('arquivar-colaborador-banco', id),
    reativarColaborador: (id) => ipcRenderer.invoke('reativar-colaborador-banco', id),
    aoAtualizarColaboradores: (funcao) => ipcRenderer.on('colaboradores-atualizados', (event, ...args) => funcao(...args)),
    abrirModalColaborador: () => ipcRenderer.send('abrir-modal-colaborador'),
    fecharModalColaborador: () => ipcRenderer.send('fechar-modal-colaborador'),
    salvarColaborador: (dados) => ipcRenderer.invoke('salvar-colaborador-banco', dados),

    // ==================== REDEFINIR SENHA DE COLABORADOR ====================
    abrirModalRedefinirSenhaColaborador: () => ipcRenderer.send('abrir-modal-redefinir-senha-colaborador'),
    fecharModalRedefinirSenhaColaborador: () => ipcRenderer.send('fechar-modal-redefinir-senha-colaborador'),
    redefinirSenhaColaborador: (dados) => ipcRenderer.invoke('redefinir-senha-colaborador', dados),

    // ==================== VER COLABORADORES DO GRUPO ====================
    abrirModalVerColaboradores: () => ipcRenderer.send('abrir-modal-ver-colaboradores'),
    fecharModalVerColaboradores: () => ipcRenderer.send('fechar-modal-ver-colaboradores'),
    pedirColaboradoresDoGrupo: (idGrupo) => ipcRenderer.invoke('buscar-colaboradores-do-grupo', idGrupo),
    moverColaboradorDeGrupo: (dados) => ipcRenderer.invoke('mover-colaborador-de-grupo', dados),
});