document.addEventListener('DOMContentLoaded', async () => {

  // A lista das 13 permissões e o desenho das caixinhas vêm do arquivo
  // compartilhado ../../compartilhado/permissoes.js (carregado no HTML).

  const telaTemplates = document.getElementById('tela-templates');
  const telaFormulario = document.getElementById('tela-formulario');
  const listaTemplates = document.getElementById('lista-templates');
  const listaCategorias = document.getElementById('lista-categorias');
  const grupoTitulo = document.getElementById('grupo-titulo');
  const btnVoltarTemplates = document.getElementById('btn-voltar-templates');
  const footerFormulario = document.getElementById('footer-formulario');
  const inputNome = document.getElementById('grupo-nome');
  const inputDescricao = document.getElementById('grupo-descricao');
  const contadorPermissoes = document.getElementById('contador-permissoes');
  const btnCancelar = document.getElementById('btn-cancelar');
  const btnFecharTopo = document.getElementById('btn-fechar-topo');
  const btnSalvarGrupo = document.getElementById('btn-salvar-grupo');

  let grupoEmEdicao = null;
  let permissoesSelecionadas = new Set();

  const grupoSalvo = localStorage.getItem('grupoParaEditar');
  if (grupoSalvo) {
    try {
      grupoEmEdicao = JSON.parse(grupoSalvo);
    } catch (err) {
      console.error('Erro ao ler grupo para edição:', err);
    }
    localStorage.removeItem('grupoParaEditar');
  }

  function fecharJanela() {
    window.apiAcesso.fecharModalGrupo();
  }

  btnCancelar.addEventListener('click', fecharJanela);
  btnFecharTopo.addEventListener('click', fecharJanela);

  function irParaFormulario(permissoesIniciais) {
    permissoesSelecionadas = new Set(permissoesIniciais || []);
    telaTemplates.style.display = 'none';
    telaFormulario.style.display = 'block';
    footerFormulario.style.display = 'flex';
    renderizarCategorias();
  }

  function voltarParaTemplates() {
    telaFormulario.style.display = 'none';
    telaTemplates.style.display = 'block';
    footerFormulario.style.display = 'none';
  }

  btnVoltarTemplates.addEventListener('click', voltarParaTemplates);

  function renderizarCategorias() {
    desenharListaPermissoes(listaCategorias, permissoesSelecionadas, atualizarContador);
    atualizarContador();
  }

  function atualizarContador() {
    const total = permissoesSelecionadas.size;
    contadorPermissoes.textContent = `${total} selecionada${total !== 1 ? 's' : ''}`;
  }

  async function montarPasso1() {
    listaTemplates.innerHTML = `<p style="color:#999; font-size:0.85rem;">Carregando modelos existentes...</p>`;

    const templates = [
      {
        nome: 'Começar do zero',
        descricaoTemplate: 'Crie o modelo do zero e marque cada permissão.',
        icone: 'ri-file-add-line',
        permissoes: []
      }
    ];

    try {
      const grupos = await window.apiAcesso.pedirGruposPermissao();
      grupos.forEach(g => {
        templates.push({
          nome: g.nome,
          descricaoTemplate: `${(g.permissoes || []).length} permissões`,
          icone: 'ri-shield-user-line',
          permissoes: g.permissoes || []
        });
      });
    } catch (erro) {
      console.error('Erro ao carregar modelos existentes:', erro);
    }

    listaTemplates.innerHTML = '';
    templates.forEach(tpl => {
      const card = document.createElement('div');
      card.className = 'template-card';
      card.innerHTML = `
        <div class="template-icon"><i class="${tpl.icone}"></i></div>
        <div class="template-info">
          <strong>${tpl.nome}</strong>
          <p>${tpl.descricaoTemplate}</p>
        </div>
      `;
      card.addEventListener('click', () => {
        btnVoltarTemplates.style.display = 'inline-block';
        irParaFormulario(tpl.permissoes);
      });
      listaTemplates.appendChild(card);
    });
  }

  // ---- Decide qual modo abrir ----
  if (grupoEmEdicao) {
    grupoTitulo.textContent = 'Editar Modelo de Permissão';
    inputNome.value = grupoEmEdicao.nome || '';
    inputDescricao.value = grupoEmEdicao.descricao || '';
    btnVoltarTemplates.style.display = 'none';
    irParaFormulario(grupoEmEdicao.permissoes || []);
  } else {
    grupoTitulo.textContent = 'Novo Modelo de Permissão';
    await montarPasso1();
  }

  // ---- Salvar ----
  btnSalvarGrupo.addEventListener('click', async () => {
    const nome = inputNome.value.trim();

    btnSalvarGrupo.disabled = true;

    const dadosGrupo = {
      nome,
      descricao: inputDescricao.value.trim(),
      permissoes: Array.from(permissoesSelecionadas)
    };

    if (grupoEmEdicao) {
      dadosGrupo.id = grupoEmEdicao.id;
    }

    try {
      const resposta = await window.apiAcesso.salvarGrupoPermissao(dadosGrupo);
      if (resposta.sucesso) {
        fecharJanela();
      } else {
        btnSalvarGrupo.disabled = false;
      }
    } catch (erro) {
      console.error('Erro ao salvar grupo:', erro);
      btnSalvarGrupo.disabled = false;
    }
  });
});