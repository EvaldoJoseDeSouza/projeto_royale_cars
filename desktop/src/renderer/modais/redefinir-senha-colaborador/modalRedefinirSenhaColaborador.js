document.addEventListener('DOMContentLoaded', () => {
  const form = document.getElementById('form-redefinir-senha');

  let colaborador = null;
  try {
    colaborador = JSON.parse(localStorage.getItem('colaboradorParaRedefinirSenha'));
    localStorage.removeItem('colaboradorParaRedefinirSenha');
  } catch (e) {
    colaborador = null;
  }

  if (colaborador) {
    document.getElementById('texto-colaborador').textContent =
      'Defina uma nova senha para ' + (colaborador.nome || colaborador.username) + '.';
  }

  function fechar() {
    window.apiAcesso.fecharModalRedefinirSenhaColaborador();
  }
  document.getElementById('btn-cancelar').addEventListener('click', fechar);
  document.getElementById('btn-fechar-topo').addEventListener('click', fechar);

  function configurarToggleSenha(idInput, idBotao, idIcone) {
    const input = document.getElementById(idInput);
    const btn = document.getElementById(idBotao);
    const icone = document.getElementById(idIcone);
    btn.addEventListener('click', () => {
      const novoTipo = input.type === 'password' ? 'text' : 'password';
      input.type = novoTipo;
      icone.className = novoTipo === 'password' ? 'ri-eye-line' : 'ri-eye-off-line';
    });
  }
  configurarToggleSenha('nova-senha', 'btn-olho-nova-senha', 'ic-olho-nova-senha');
  configurarToggleSenha('confirmar-senha', 'btn-olho-confirmar-senha', 'ic-olho-confirmar-senha');

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!colaborador) return;

    const btn = document.getElementById('btn-salvar');
    btn.disabled = true;
    try {
      const resposta = await window.apiAcesso.redefinirSenhaColaborador({
        idColaborador: colaborador.id,
        novaSenha: document.getElementById('nova-senha').value,
        confirmarSenha: document.getElementById('confirmar-senha').value
      });
      if (resposta && resposta.sucesso) fechar();
    } catch (erro) {
      console.error('Erro ao redefinir senha:', erro);
    } finally {
      btn.disabled = false;
    }
  });
});
