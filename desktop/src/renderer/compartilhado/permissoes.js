// =====================================================================
//  As 13 permissões do sistema (arquivo compartilhado)
// ---------------------------------------------------------------------
//  São as MESMAS chaves na web, no desktop e no celular (tabela
//  usuario_permissoes do banco). Antes esta lista estava copiada em
//  vários arquivos; agora mora só aqui e quem precisa carrega com:
//
//     <script src="../../compartilhado/permissoes.js"></script>
//
//  Quem usa: o modal de modelos, o modal de colaborador e o dashboard.
//
//  "dependeDe" lista o que é ligado junto: não adianta poder cadastrar
//  cliente sem poder ver a lista de clientes.
// =====================================================================

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

// Total de permissões que existem (13). Usado em "5 de 13".
const TOTAL_PERMISSOES = CATEGORIAS_PERMISSOES.reduce((soma, cat) => soma + cat.permissoes.length, 0);

// Devolve o nome "de gente" de uma chave. Ex.: 'clientes_ver' → 'Ver Clientes'
function tituloDaPermissao(chave) {
  for (const cat of CATEGORIAS_PERMISSOES) {
    const achada = cat.permissoes.find((p) => p.chave === chave);
    if (achada) return achada.titulo;
  }
  return chave;
}

// Desenha a lista de caixinhas, separada por categoria (abre e fecha).
//   container    → a <div> onde a lista aparece
//   selecionadas → um Set com as chaves marcadas (é alterado aqui dentro)
//   aoMudar      → função chamada sempre que alguém marca ou desmarca
function desenharListaPermissoes(container, selecionadas, aoMudar) {
  // Guarda quais categorias estavam abertas antes de redesenhar
  const categoriasAbertas = new Set();
  container.querySelectorAll('.categoria-permissao.aberta').forEach((div) => {
    categoriasAbertas.add(div.querySelector('strong').textContent);
  });

  container.innerHTML = '';

  CATEGORIAS_PERMISSOES.forEach((cat) => {
    const marcadas = cat.permissoes.filter((p) => selecionadas.has(p.chave)).length;

    const divCategoria = document.createElement('div');
    divCategoria.className = 'categoria-permissao';
    if (categoriasAbertas.has(cat.categoria)) divCategoria.classList.add('aberta');

    divCategoria.innerHTML = `
      <div class="categoria-header">
        <div class="categoria-info">
          <i class="ri-arrow-right-s-line categoria-seta"></i>
          <strong>${cat.categoria}</strong>
        </div>
        <span class="categoria-contagem">${marcadas} de ${cat.permissoes.length}</span>
      </div>
      <div class="categoria-lista"></div>
    `;

    // Clicar no título abre esta categoria e fecha as outras
    divCategoria.querySelector('.categoria-header').addEventListener('click', () => {
      const estavaAberta = divCategoria.classList.contains('aberta');
      container.querySelectorAll('.categoria-permissao.aberta').forEach((d) => d.classList.remove('aberta'));
      if (!estavaAberta) divCategoria.classList.add('aberta');
    });

    const listaInterna = divCategoria.querySelector('.categoria-lista');

    cat.permissoes.forEach((perm) => {
      const label = document.createElement('label');
      label.className = 'permissao-item';
      label.innerHTML = `
        <div>
          <strong>${perm.titulo}</strong>
          <p>${perm.descricao}</p>
        </div>
        <input type="checkbox" data-chave="${perm.chave}" ${selecionadas.has(perm.chave) ? 'checked' : ''}>
      `;

      const checkbox = label.querySelector('input');
      checkbox.addEventListener('change', () => {
        if (checkbox.checked) {
          selecionadas.add(perm.chave);
          (perm.dependeDe || []).forEach((chave) => selecionadas.add(chave));
        } else {
          selecionadas.delete(perm.chave);
        }
        desenharListaPermissoes(container, selecionadas, aoMudar);
        if (aoMudar) aoMudar();
      });

      listaInterna.appendChild(label);
    });

    container.appendChild(divCategoria);
  });

  // Trava as caixas de que uma permissão marcada precisa (não dá para desmarcar)
  CATEGORIAS_PERMISSOES.forEach((cat) => {
    cat.permissoes.forEach((perm) => {
      if (!perm.dependeDe || !selecionadas.has(perm.chave)) return;
      perm.dependeDe.forEach((chave) => {
        const caixaPai = container.querySelector(`input[data-chave="${chave}"]`);
        if (caixaPai) caixaPai.disabled = true;
      });
    });
  });
}
