document.addEventListener('DOMContentLoaded', async () => {

  // As 13 permissões do banco unificado: as MESMAS chaves na web, no
  // desktop e no celular. "dependeDe" lista o que é ligado junto: não
  // adianta poder cadastrar cliente sem poder ver a lista de clientes.
  const CATEGORIAS_PERMISSOES = [
    {
      categoria: 'Clientes',
      permissoes: [
        { chave: 'clientes_ver', titulo: 'Ver Clientes', descricao: 'Vê a lista e a ficha dos clientes.' },
        { chave: 'clientes_gerenciar', titulo: 'Cadastrar e Editar Clientes', descricao: 'Cadastra novos clientes e edita os existentes.', dependeDe: ['clientes_ver'] },
        { chave: 'clientes_arquivar', titulo: 'Arquivar Clientes', descricao: 'Arquiva e reativa cadastros de clientes.', dependeDe: ['clientes_ver'] }
      ]
    },
    {
      categoria: 'Frota',
      permissoes: [
        { chave: 'veiculos_ver', titulo: 'Ver Frota', descricao: 'Vê a lista de veículos.' },
        { chave: 'veiculos_gerenciar', titulo: 'Cadastrar e Editar Veículos', descricao: 'Cadastra veículos e edita os dados, inclusive o preço da diária.', dependeDe: ['veiculos_ver'] },
        { chave: 'veiculos_arquivar', titulo: 'Arquivar Veículos', descricao: 'Arquiva e reativa veículos da frota.', dependeDe: ['veiculos_ver'] }
      ]
    },
    {
      categoria: 'Locações',
      permissoes: [
        { chave: 'locacoes_ver', titulo: 'Ver Locações', descricao: 'Vê as locações em andamento e o histórico.' },
        { chave: 'locacoes_gerenciar', titulo: 'Registrar Retirada e Devolução', descricao: 'Registra novas locações e a devolução dos carros.', dependeDe: ['locacoes_ver', 'clientes_ver', 'veiculos_ver'] },
        { chave: 'locacoes_cancelar', titulo: 'Cancelar Locações', descricao: 'Cancela uma locação em andamento, informando o motivo.', dependeDe: ['locacoes_ver'] }
      ]
    },
    {
      categoria: 'Manutenção',
      permissoes: [
        { chave: 'manutencoes', titulo: 'Manutenção', descricao: 'Envia veículos para a oficina e libera informando o custo.', dependeDe: ['veiculos_ver'] }
      ]
    },
    {
      categoria: 'Financeiro e Relatórios',
      permissoes: [
        { chave: 'financeiro', titulo: 'Ver Financeiro', descricao: 'Vê faturamento, custos e resultado do mês.' },
        { chave: 'relatorios', titulo: 'Relatórios', descricao: 'Gera relatórios de clientes, frota, locações e manutenções.' },
        { chave: 'relatorios_financeiros', titulo: 'Valores nos Relatórios', descricao: 'Vê o relatório de faturamento e as colunas de valores.', dependeDe: ['relatorios'] }
      ]
    }
  ];

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
    // Guarda quais categorias estavam abertas antes de redesenhar
    const categoriasAbertas = new Set();
    listaCategorias.querySelectorAll('.categoria-permissao.aberta').forEach(div => {
      const nomeCategoria = div.querySelector('strong').textContent;
      categoriasAbertas.add(nomeCategoria);
    });

    listaCategorias.innerHTML = '';

    CATEGORIAS_PERMISSOES.forEach(cat => {
      const totalCategoria = cat.permissoes.length;
      const marcadasCategoria = cat.permissoes.filter(p => permissoesSelecionadas.has(p.chave)).length;

      const divCategoria = document.createElement('div');
      divCategoria.className = 'categoria-permissao';
      if (categoriasAbertas.has(cat.categoria)) {
        divCategoria.classList.add('aberta');
      }

      divCategoria.innerHTML = `
      <div class="categoria-header">
        <div class="categoria-info">
          <i class="ri-arrow-right-s-line categoria-seta"></i>
          <strong>${cat.categoria}</strong>
        </div>
        <span class="categoria-contagem">${marcadasCategoria} de ${totalCategoria}</span>
      </div>
      <div class="categoria-lista"></div>
    `;

      const header = divCategoria.querySelector('.categoria-header');
      header.addEventListener('click', () => {
        const estavaAberta = divCategoria.classList.contains('aberta');

        // Fecha todas as categorias antes de decidir o que fazer com a clicada
        listaCategorias.querySelectorAll('.categoria-permissao.aberta').forEach(d => {
          d.classList.remove('aberta');
        });

        if (!estavaAberta) {
          divCategoria.classList.add('aberta');
        }
      });

      const listaInterna = divCategoria.querySelector('.categoria-lista');

      cat.permissoes.forEach(perm => {
        const label = document.createElement('label');
        label.className = 'permissao-item';
        label.innerHTML = `
        <div>
          <strong>${perm.titulo}</strong>
          <p>${perm.descricao}</p>
        </div>
        <input type="checkbox" data-chave="${perm.chave}" ${permissoesSelecionadas.has(perm.chave) ? 'checked' : ''}>
      `;

        const checkbox = label.querySelector('input');
        checkbox.addEventListener('change', () => {
          if (checkbox.checked) {
            permissoesSelecionadas.add(perm.chave);
            (perm.dependeDe || []).forEach(chave => permissoesSelecionadas.add(chave));
          } else {
            permissoesSelecionadas.delete(perm.chave);
          }
          renderizarCategorias();
        });

        listaInterna.appendChild(label);
      });

      listaCategorias.appendChild(divCategoria);
    });

    CATEGORIAS_PERMISSOES.forEach(cat => {
      cat.permissoes.forEach(perm => {
        if (!perm.dependeDe || !permissoesSelecionadas.has(perm.chave)) return;
        // Trava as caixas de que esta permissão precisa (não dá para desmarcar)
        perm.dependeDe.forEach(chave => {
          const checkboxPai = listaCategorias.querySelector(`input[data-chave="${chave}"]`);
          if (checkboxPai) checkboxPai.disabled = true;
        });
      });
    });

    contadorPermissoes.textContent = `${permissoesSelecionadas.size} selecionada${permissoesSelecionadas.size !== 1 ? 's' : ''}`;
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