document.addEventListener('DOMContentLoaded', async () => {
  const form = document.getElementById('form-colaborador');
  const selectGrupo = document.getElementById('colab-grupo');
  const blocoSenha = document.getElementById('bloco-senha');
  const titulo = document.getElementById('titulo-modal-colaborador');

  // Se o dashboard deixou um colaborador no localStorage, estamos EDITANDO.
  let colaboradorEditando = null;
  try {
    const salvo = localStorage.getItem('colaboradorParaEditar');
    if (salvo) colaboradorEditando = JSON.parse(salvo);
    localStorage.removeItem('colaboradorParaEditar');
  } catch (e) {
    colaboradorEditando = null;
  }

  function fechar() {
    window.apiAcesso.fecharModalColaborador();
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
  configurarToggleSenha('colab-senha', 'btn-olho-colab-senha', 'ic-olho-colab-senha');
  configurarToggleSenha('colab-confirmar-senha', 'btn-olho-colab-confirmar', 'ic-olho-colab-confirmar');

  // Preenche o <select> com os grupos da empresa. Se vier um id, já o seleciona.
  async function carregarGrupos(idParaSelecionar) {
    const grupos = await window.apiAcesso.pedirGruposPermissao();
    const valorAtual = idParaSelecionar != null ? String(idParaSelecionar) : selectGrupo.value;

    selectGrupo.innerHTML = '<option value="">Selecione um grupo...</option>';
    grupos.forEach(g => {
      const opt = document.createElement('option');
      opt.value = g.id;
      opt.textContent = g.nome;
      selectGrupo.appendChild(opt);
    });

    if (valorAtual) selectGrupo.value = valorAtual;
  }

  await carregarGrupos(colaboradorEditando ? colaboradorEditando.id_grupo_permissao : null);

  // Modo edição: preenche os campos e esconde a senha (a senha é redefinida em outro modal)
  if (colaboradorEditando) {
    titulo.textContent = 'Editar Colaborador';
    blocoSenha.style.display = 'none';
    document.getElementById('colab-nome').value = colaboradorEditando.nome || '';
    document.getElementById('colab-username').value = colaboradorEditando.username || '';
    document.getElementById('colab-email').value = colaboradorEditando.email || '';
    document.getElementById('colab-telefone').value = colaboradorEditando.telefone || '';
  }

  // "Criar novo grupo": abre o modal de grupo; quando salvar, o grupo novo já vem selecionado.
  document.getElementById('btn-criar-grupo').addEventListener('click', () => {
    try { localStorage.removeItem('grupoParaEditar'); } catch (e) { }
    window.apiAcesso.abrirModalGrupo();
  });

  window.apiAcesso.aoAtualizarGrupos(async (info) => {
    await carregarGrupos(info && info.id ? info.id : null);
  });

  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const dados = {
      id: colaboradorEditando ? colaboradorEditando.id : null,
      nome: document.getElementById('colab-nome').value,
      username: document.getElementById('colab-username').value,
      email: document.getElementById('colab-email').value,
      telefone: document.getElementById('colab-telefone').value,
      id_grupo_permissao: selectGrupo.value,
      senha: document.getElementById('colab-senha').value,
      confirmarSenha: document.getElementById('colab-confirmar-senha').value
    };

    const btn = document.getElementById('btn-salvar');
    btn.disabled = true;
    try {
      const resposta = await window.apiAcesso.salvarColaborador(dados);
      if (resposta && resposta.sucesso) fechar();
    } catch (erro) {
      console.error('Erro ao salvar colaborador:', erro);
    } finally {
      btn.disabled = false;
    }
  });
});
