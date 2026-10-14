document.addEventListener('DOMContentLoaded', () => {
  const form = document.getElementById('form-trocar-senha');
  const btnCancelar = document.getElementById('btn-cancelar');
  const btnFecharTopo = document.getElementById('btn-fechar-topo');

  function fecharJanela() {
    window.apiAcesso.fecharModalTrocarSenha();
  }

  btnCancelar.addEventListener('click', fecharJanela);
  btnFecharTopo.addEventListener('click', fecharJanela);

  function configurarToggleSenha(idInput, idBotao, idIcone){
    const inputSenha = document.getElementById(idInput);
    const btnOlho = document.getElementById(idBotao);
    const iconeOlho = document.getElementById(idIcone);

    if (inputSenha && btnOlho && iconeOlho) {
      btnOlho.addEventListener('click', () => {
        const tipoAtual = inputSenha.getAttribute('type');
        const novoTipo = tipoAtual === 'password' ? 'text' : 'password';
        inputSenha.setAttribute('type', novoTipo);

        iconeOlho.className = novoTipo === 'password' ? 'ri-eye-line' : 'ri-eye-off-line';
      });
    }
  }

  configurarToggleSenha('senha-atual', 'btn-olho-senha-atual', 'ic-olho-senha-atual');
  configurarToggleSenha('nova-senha', 'btn-olho-nova-senha', 'ic-olho-nova-senha');
  configurarToggleSenha('confirmar-nova-senha', 'btn-olho-confirmar-nova-senha', 'ic-olho-confirmar-nova-senha');  

  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const senhaAtual = document.getElementById('senha-atual').value;
    const novaSenha = document.getElementById('nova-senha').value;
    const confirmarNovaSenha = document.getElementById('confirmar-nova-senha').value;

    if (novaSenha.length < 6) {
      alert('Sua nova senha deve conter pelo menos 6 caracteres por motivos de segurança.');
      return;
    }

    if (novaSenha !== confirmarNovaSenha) {
      alert('As senhas não coincidem. Verifique e tente novamente.');
      return;
    }

    const btnSalvar = form.querySelector('.btn-save');
    if (btnSalvar) btnSalvar.disabled = true;

    try {
      const resposta = await window.apiAcesso.trocarSenhaLogado({ senhaAtual, novaSenha });

      if (resposta.sucesso) {
        window.apiAcesso.fecharModalTrocarSenha();
      }
    } catch (erro) {
      console.error('Erro ao trocar senha:', erro);
    } finally {
      if (btnSalvar) btnSalvar.disabled = false;
    }
  });
});