document.addEventListener('DOMContentLoaded', () => {
    const elTitulo = document.getElementById('confirm-titulo');
    const elMensagem = document.getElementById('confirm-mensagem');
    const elIcone = document.getElementById('confirm-icone');
    const btnCancelar = document.getElementById('btn-cancelar-confirm');
    const btnConfirmar = document.getElementById('btn-confirmar-acao');
    const btnFecharTopo = document.getElementById('btn-fechar-topo');

    const iconesPorTipo = {
        perigo: 'ri-error-warning-line',
        neutro: 'ri-question-line',
        sucesso: 'ri-checkbox-circle-line',
        erro: 'ri-close-circle-line'
    };

    window.apiAcesso.aoReceberDadosConfirmacao((dados) => {
        const tipo = dados.tipo || 'neutro';
        const tipoCancelar = dados.tipoCancelar || 'cinza';

        if (elTitulo) elTitulo.textContent = dados.titulo || 'Aviso';
        if (elMensagem) elMensagem.textContent = dados.mensagem || '';

        if (elIcone) {
            elIcone.className = `${iconesPorTipo[tipo] || iconesPorTipo.neutro} icone-${tipo}`;
        }

        if (btnConfirmar) {
            btnConfirmar.textContent = dados.textoConfirmar || 'Confirmar';
            btnConfirmar.classList.remove('cor-perigo', 'cor-erro', 'cor-neutro', 'cor-sucesso', 'cor-cinza');
            btnConfirmar.classList.add(`cor-${tipo}`);
        }

        if (btnCancelar) {
            btnCancelar.classList.remove('cor-perigo', 'cor-erro', 'cor-neutro', 'cor-sucesso', 'cor-cinza');
            btnCancelar.classList.add(`cor-${tipoCancelar}`);
            btnCancelar.style.display = dados.modo === 'aviso' ? 'none' : '';
        };

    });

    btnCancelar.addEventListener('click', () => window.apiAcesso.responderConfirmacao(false));
    btnFecharTopo.addEventListener('click', () => window.apiAcesso.responderConfirmacao(false));
    btnConfirmar.addEventListener('click', () => window.apiAcesso.responderConfirmacao(true));
});