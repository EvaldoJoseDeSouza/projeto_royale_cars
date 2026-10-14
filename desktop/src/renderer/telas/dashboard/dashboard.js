document.addEventListener('DOMContentLoaded', () => {

  const menuItems = document.querySelectorAll('.menu-item:not(#btn-locacoes-master), .stat-card.clickable, #link-ver-todas, .dropdown-item:not(#btn-sair)');
  const views = document.querySelectorAll('.content-view');
  const pageTitle = document.getElementById('current-page-title');

  const containerFrota = document.getElementById('container-frota');
  const containerClientes = document.getElementById('container-clientes');
  const tabelaLocacoesAtivasBody = document.getElementById('tabela-locacoes-ativas-body');
  const tabelaLocacoesHistoricoBody = document.getElementById('tabela-locacoes-historico-body');
  const tabelaFinanceiroBody = document.getElementById('tabela-financeiro-body');
  const tabelaUltimasLocacoesBody = document.getElementById('tabela-ultimas-locacoes-body');
  const dashSublegenda = document.getElementById('dash-faturamento-sublegenda');

  const dashFaturamento = document.getElementById('dash-faturamento');
  const dashLocacoesAtivas = document.getElementById('dash-locacoes-ativas');
  const dashClientesAtivos = document.getElementById('dash-clientes-ativos');
  const dashStatusFrota = document.getElementById('dash-status-frota');

  const btnAbrirModal = document.getElementById('btn-abrir-cadastro-carro');
  const btnAbrirModalCliente = document.getElementById('btn-abrir-cadastro-cliente');
  const btnAbrirModalLocacao = document.getElementById('btn-abrir-cadastro-locacao');
  const btnPerfil = document.getElementById('btn-perfil');
  const userDropdown = document.getElementById('user-dropdown');
  const btnSair = document.getElementById('btn-sair');

  const btnLocacoesMaster = document.getElementById('btn-locacoes-master');
  const submenuLocacoes = document.getElementById('submenu-locacoes');
  const arrowIcon = document.querySelector('#btn-locacoes-master .arrow-icon');

  const containerGruposPermissao = document.getElementById('container-grupos-permissao');
  const btnAdministracaoMaster = document.getElementById('btn-administracao-master');
  const submenuAdministracao = document.getElementById('submenu-administracao');
  const arrowIconAdmin = document.querySelector('.arrow-icon-admin');

  let dadosFinanceirosOriginais = null;

  let listaFrotaAtual = [];
  let listaClientesAtual = [];
  let filtroStatusAtivo = 'Todos';

  const inputBuscaFrota = document.getElementById('busca-frota');
  const inputBuscaClientes = document.getElementById('busca-clientes');
  const btnFiltroStatus = document.getElementById('btn-filtro-status');
  const filtroStatusMenu = document.getElementById('filtro-status-menu');
  const filtroStatusLabel = document.getElementById('filtro-status-label');
  const filtroStatusWrapper = document.getElementById('filtro-status-wrapper');

  let modoArquivadoFrota = false;
  let modoArquivadoClientes = false;
  let listaFrotaArquivadaAtual = [];
  let listaClientesArquivadosAtual = [];

  const btnToggleArquivadosFrota = document.getElementById('btn-toggle-arquivados-frota');
  const textoToggleArquivadosFrota = document.getElementById('texto-toggle-arquivados-frota');
  const iconeToggleArquivadosFrota = document.getElementById('icone-toggle-arquivados-frota');

  const btnToggleArquivadosClientes = document.getElementById('btn-toggle-arquivados-clientes');
  const textoToggleArquivadosClientes = document.getElementById('texto-toggle-arquivados-clientes');
  const iconeToggleArquivadosClientes = document.getElementById('icone-toggle-arquivados-clientes');

  // ---------- PERMISSÕES DO USUÁRIO LOGADO (Etapa 4) ----------
  // Preenchidas em carregarUsuarioLogado(). O chefe tem acesso total.
  let ehAdministrador = false;
  let permissoesUsuario = [];

  function tem(chave) {
    return ehAdministrador || permissoesUsuario.includes(chave);
  }

  // Remove de um card os itens do menu ⋮ que o usuário não pode usar.
  // Se não sobrar nenhum item, remove também o próprio botão ⋮.
  function aplicarPermissoesNoCard(card, mapaSeletorPermissao) {
    Object.keys(mapaSeletorPermissao).forEach(seletor => {
      const el = card.querySelector(seletor);
      if (el && !tem(mapaSeletorPermissao[seletor])) el.remove();
    });
    const sobrou = card.querySelector('.card-dropdown .card-dropdown-item');
    if (!sobrou) {
      const dropdown = card.querySelector('.card-dropdown');
      const botao = card.querySelector('.btn-card-options');
      if (dropdown) dropdown.remove();
      if (botao) botao.remove();
    }
  }

  // Esconde (apenas esconde) o que o usuário não tem permissão de ver/usar.
  function aplicarPermissoesNaInterface() {
    const esconderSe = (el, negado) => { if (el && negado) el.style.display = 'none'; };
    const pegar = (sel) => document.querySelector(sel);

    // Menu lateral
    esconderSe(pegar('.menu-item[data-target="view-frota"]'), !tem('ver_frota'));
    esconderSe(pegar('.menu-item[data-target="view-clientes"]'), !tem('ver_clientes'));
    esconderSe(pegar('.menu-item[data-target="view-financeiro"]'), !tem('ver_financeiro'));
    const wrapLocacoes = document.getElementById('btn-locacoes-master')?.closest('.menu-dropdown-wrapper');
    esconderSe(wrapLocacoes, !tem('ver_locacoes'));
    const wrapAdmin = document.getElementById('btn-administracao-master')?.closest('.menu-dropdown-wrapper');
    esconderSe(wrapAdmin, !tem('ver_colaboradores'));

    // Cards de resumo do Dashboard
    esconderSe(pegar('.stat-card[data-target="view-financeiro"]'), !tem('ver_financeiro'));
    esconderSe(pegar('.stat-card[data-target="view-locacoes-ativas"]'), !tem('ver_locacoes'));
    esconderSe(pegar('.stat-card[data-target="view-clientes"]'), !tem('ver_clientes'));
    esconderSe(pegar('.stat-card[data-target="view-frota"]'), !tem('ver_frota'));

    // Botões de ação das telas
    esconderSe(btnAbrirModal, !tem('editar_frota'));
    esconderSe(btnAbrirModalCliente, !tem('editar_clientes'));
    esconderSe(btnAbrirModalLocacao, !tem('criar_locacoes'));
    esconderSe(btnAbrirCadastroColaborador, !tem('criar_colaboradores'));
    esconderSe(btnAbrirModalGrupo, !tem('criar_colaboradores'));

    // Botões "Arquivados"
    esconderSe(document.getElementById('btn-toggle-arquivados-frota'), !tem('arquivar_frota'));
    esconderSe(document.getElementById('btn-toggle-arquivados-clientes'), !tem('arquivar_clientes'));
    esconderSe(btnToggleArquivadosColaboradores, !tem('excluir_colaboradores'));
  }

  let listaColaboradoresAtual = [];
  let listaColaboradoresArquivadosAtual = [];
  let modoArquivadoColaboradores = false;

  const containerColaboradores = document.getElementById('container-colaboradores');
  const inputBuscaColaboradores = document.getElementById('busca-colaboradores');
  const btnToggleArquivadosColaboradores = document.getElementById('btn-toggle-arquivados-colaboradores');
  const textoToggleArquivadosColaboradores = document.getElementById('texto-toggle-arquivados-colaboradores');
  const iconeToggleArquivadosColaboradores = document.getElementById('icone-toggle-arquivados-colaboradores');
  const btnAbrirCadastroColaborador = document.getElementById('btn-abrir-cadastro-colaborador');

  if (btnToggleArquivadosFrota) {
    btnToggleArquivadosFrota.addEventListener('click', async () => {
      modoArquivadoFrota = !modoArquivadoFrota;

      if (textoToggleArquivadosFrota) {
        textoToggleArquivadosFrota.textContent = modoArquivadoFrota ? 'Voltar para Ativos' : 'Arquivados';
      }
      if (iconeToggleArquivadosFrota) {
        iconeToggleArquivadosFrota.className = modoArquivadoFrota ? 'ri-arrow-left-line' : 'ri-archive-line';
      }

      if (modoArquivadoFrota) {
        try {
          listaFrotaArquivadaAtual = await window.apiAcesso.pedirFrotaArquivada();
        } catch (erro) {
          console.error("Erro ao carregar frota arquivada:", erro);
        }
      }

      aplicarFiltrosFrota();
    });
  }

  if (btnToggleArquivadosClientes) {
    btnToggleArquivadosClientes.addEventListener('click', async () => {
      modoArquivadoClientes = !modoArquivadoClientes;

      if (textoToggleArquivadosClientes) {
        textoToggleArquivadosClientes.textContent = modoArquivadoClientes ? 'Voltar para Ativos' : 'Arquivados';
      }
      if (iconeToggleArquivadosClientes) {
        iconeToggleArquivadosClientes.className = modoArquivadoClientes ? 'ri-arrow-left-line' : 'ri-archive-line';
      }

      if (modoArquivadoClientes) {
        try {
          listaClientesArquivadosAtual = await window.apiAcesso.pedirClientesArquivados();
        } catch (erro) {
          console.error("Erro ao carregar clientes arquivados:", erro);
        }
      }

      aplicarFiltrosClientes();
    });
  }

  const titulosPorView = {
    'view-resumo': 'Dashboard',
    'view-frota': 'Frota de Veículos',
    'view-clientes': 'Gestão de Clientes',
    'view-locacoes-ativas': 'Locações em Andamento',
    'view-locacoes-historico': 'Histórico de Locações',
    'view-financeiro': 'Painel Financeiro & Fluxo de Caixa',
    'view-configuracoes': 'Configurações da Conta',
    'view-colaboradores': 'Gerenciar Colaboradores',
    'view-grupos-permissao': 'Grupos de Permissão'
  };

  async function carregarResumoDashboard() {
    try {
      const dadosFin = await window.apiAcesso.pedirDadosFinanceiros();

      const listaLocacoesAtivas = await window.apiAcesso.pedirLocacoesAtivas();
      const listaClientes = await window.apiAcesso.pedirClientes();
      const listaFrota = await window.apiAcesso.pedirFrota();

      const formatador = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });

      if (dashFaturamento && dadosFin && dadosFin.sucesso) {
        dashFaturamento.textContent = formatador.format(dadosFin.indicadores.faturamentoTotal);

        if (dashSublegenda) {
          const variacao = dadosFin.indicadores.variacaoPercentual;

          if (variacao >= 0) {
            dashSublegenda.innerHTML = `↑ ${variacao}% em relação ao mês passado`;
            dashSublegenda.style.color = '#10b981';
          } else {
            dashSublegenda.innerHTML = `↓ ${Math.abs(variacao)}% em relação ao mês passado`;
            dashSublegenda.style.color = '#ef4444';
          }
        }
      }

      if (dashLocacoesAtivas && listaLocacoesAtivas) {
        dashLocacoesAtivas.textContent = listaLocacoesAtivas.length;
      }

      if (dashClientesAtivos && listaClientes) {
        dashClientesAtivos.textContent = listaClientes.length;
      }

      if (dashStatusFrota && listaFrota) {
        dashStatusFrota.textContent = listaFrota.length;
      }

      if (tabelaUltimasLocacoesBody && listaLocacoesAtivas) {
        tabelaUltimasLocacoesBody.innerHTML = '';

        if (listaLocacoesAtivas.length === 0) {
          tabelaUltimasLocacoesBody.innerHTML = `<tr><td colspan="4" style="text-align: center; color: var(--text-muted); padding: 15px;">Nenhuma locação ativa no momento.</td></tr>`;
          return;
        }

        const ultimasCinco = listaLocacoesAtivas.slice(0, 5);

        ultimasCinco.forEach(loc => {
          const tr = document.createElement('tr');
          const dataSaida = new Date(loc.data_inicio).toLocaleDateString('pt-BR', { timeZone: 'UTC' });

          tr.innerHTML = `
            <td><strong>${loc.veiculos?.modelo || 'Desconhecido'}</strong> (${loc.veiculos?.placa || ''})</td>
            <td>${loc.clientes?.nome || 'Cliente Oculto'}</td>
            <td>${dataSaida}</td>
            <td><span class="badge badge-green">${loc.status}</span></td>
          `;
          tabelaUltimasLocacoesBody.appendChild(tr);
        });
      }
    } catch (erro) {
      console.error("Erro ao renderizar o resumo do dashboard:", erro);
    }
  }

  async function carregarUsuarioLogado() {
    try {
      if (!window.apiAcesso || !window.apiAcesso.pedirUsuarioLogado) return;

      const usuario = await window.apiAcesso.pedirUsuarioLogado();
      if (!usuario) return;

      ehAdministrador = usuario.cargo === 'chefe';
      permissoesUsuario = Array.isArray(usuario.permissoes) ? usuario.permissoes : [];
      aplicarPermissoesNaInterface();

      const nomeExibicao = usuario.nome || usuario.username || 'Usuario';

      const elNomeSidebar = document.getElementById('header-usuario-nome');
      const elEmailSidebar = document.getElementById('header-usuario-email');
      const elAvatarInicial = document.getElementById('header-avatar-inicial');
      const elNomeTopBar = document.getElementById('top-bar-usuario-nome');

      if (elNomeSidebar) elNomeSidebar.textContent = nomeExibicao;
      if (elEmailSidebar) elEmailSidebar.textContent = usuario.email || '';
      if (elAvatarInicial) elAvatarInicial.textContent = nomeExibicao.charAt(0).toUpperCase();
      if (elNomeTopBar) elNomeTopBar.textContent = nomeExibicao;
    } catch (erro) {
      console.error("Erro ao carregar usuário logado no rodapé/toto:", erro);
    }
  }

  if (inputBuscaFrota) {
    inputBuscaFrota.addEventListener('input', aplicarFiltrosFrota);
  }

  if (inputBuscaClientes) {
    inputBuscaClientes.addEventListener('input', aplicarFiltrosClientes);
  }

  if (btnFiltroStatus && filtroStatusMenu && filtroStatusWrapper) {
    btnFiltroStatus.addEventListener('click', (e) => {
      e.stopPropagation();
      filtroStatusMenu.classList.toggle('show');
      filtroStatusWrapper.classList.toggle('aberto');
    })

    filtroStatusMenu.querySelectorAll('.filtro-dropdown-item').forEach(item => {
      item.addEventListener('click', () => {
        filtroStatusAtivo = item.getAttribute('data-status');
        filtroStatusLabel.textContent = filtroStatusAtivo;

        filtroStatusMenu.querySelectorAll('.filtro-dropdown-item').forEach(i => i.classList.remove('active'));
        item.classList.add('active');

        filtroStatusMenu.classList.remove('show');
        filtroStatusWrapper.classList.remove('aberto');

        aplicarFiltrosFrota();
      });
    });
  }

  function renderizarFrota(listaCarros, modoArquivado = false) {
    if (!containerFrota) return;
    containerFrota.innerHTML = '';

    if (listaCarros.length === 0) {
      containerFrota.innerHTML = `<p style="color: var(--text-muted); padding: 20px;">${modoArquivado ? 'Nenhum veículo arquivado.' : 'Nenhum veículo encontrado.'}</p>`;
      return;
    }

    listaCarros.forEach(carro => {
      let classeStatus = "status-disponivel";
      if (carro.status === "Alugado") classeStatus = "status-alugado";
      if (carro.status === "Em Manutenção") classeStatus = "status-manutencao";

      const precoFormatado = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(carro.diaria);
      const card = document.createElement('div');
      card.className = modoArquivado ? 'vehicle-card card-arquivado' : 'vehicle-card';

      const dropdownHtml = modoArquivado
        ? `<button class="card-dropdown-item reativar-btn" data-id="${carro.id}"><i class="ri-arrow-go-back-line"></i> Reativar</button>`
        : `<button class="card-dropdown-item edit-btn" data-id="${carro.id}"><i class="ri-edit-line"></i> Editar</button>
         <button class="card-dropdown-item delete-item archive-btn" data-id="${carro.id}"><i class="ri-archive-line"></i> Arquivar</button>`;

      card.innerHTML = `
      <button class="btn-card-options"><i class="ri-more-2-fill"></i></button>
      <div class="card-dropdown">
        ${dropdownHtml}
      </div>
      <span class="status-badge ${classeStatus}">${carro.status}</span>
      <div class="vehicle-info">
        <h4>${carro.modelo}</h4>
        <p>${carro.marca}</p>
      </div>
      <div class="vehicle-details">
        <span class="vehicle-plate">${carro.placa}</span>
        <span class="vehicle-price">${precoFormatado}/dia</span>
      </div>
    `;

      const btnOptions = card.querySelector('.btn-card-options');
      const dropdown = card.querySelector('.card-dropdown');

      btnOptions.addEventListener('click', (e) => {
        e.stopPropagation();
        document.querySelectorAll('.card-dropdown').forEach(d => { if (d !== dropdown) d.classList.remove('show'); });
        dropdown.classList.toggle('show');
      });

      if (modoArquivado) {
        card.querySelector('.reativar-btn').addEventListener('click', async (e) => {
          e.stopPropagation();
          dropdown.classList.remove('show');
          await window.apiAcesso.reativarVeiculo(carro.id);
        });
      } else {
        card.querySelector('.edit-btn').addEventListener('click', (e) => {
          e.stopPropagation();
          dropdown.classList.remove('show');
          localStorage.setItem('veiculoParaEditar', JSON.stringify(carro));
          window.apiAcesso.abrirModalCadastro();
        });

        card.querySelector('.archive-btn').addEventListener('click', async (e) => {
          e.stopPropagation();
          dropdown.classList.remove('show');

          const confirmou = await window.apiAcesso.confirmar({
            titulo: "Arquivar Veículo",
            mensagem: "Quer mesmo arquivar este veículo? Ele será movido para os arquivados e não aparecerá mais nas listagens ativas. O histórico de locações será mantido, e você pode reativá-lo quando quiser.",
            textoConfirmar: "Arquivar",
            tipo: "perigo"
          });

          if (confirmou) {
            await window.apiAcesso.arquivarVeiculo(carro.id);
          }
        });
      }

      aplicarPermissoesNoCard(card, {
        '.edit-btn': 'editar_frota',
        '.archive-btn': 'arquivar_frota',
        '.reativar-btn': 'arquivar_frota'
      });
      containerFrota.appendChild(card);
    });
  }

  function aplicarFiltrosFrota() {
    const termo = (inputBuscaFrota?.value || '').trim().toLowerCase();
    const listaBase = modoArquivadoFrota ? listaFrotaArquivadaAtual : listaFrotaAtual;
    let listaFiltrada = listaBase;

    if (termo) {
      listaFiltrada = listaFiltrada.filter(carro =>
        (carro.placa || '').toLowerCase().includes(termo) ||
        (carro.modelo || '').toLowerCase().includes(termo) ||
        (carro.marca || '').toLowerCase().includes(termo)
      );
    }

    if (filtroStatusAtivo !== 'Todos') {
      listaFiltrada = listaFiltrada.filter(carro => carro.status === filtroStatusAtivo);
    }

    renderizarFrota(listaFiltrada, modoArquivadoFrota);
  }

  function aplicarFiltrosClientes() {
    const termo = (inputBuscaClientes?.value || '').trim().toLowerCase();
    const listaBase = modoArquivadoClientes ? listaClientesArquivadosAtual : listaClientesAtual;
    let listaFiltrada = listaBase;

    if (termo) {
      listaFiltrada = listaFiltrada.filter(cliente =>
        (cliente.nome || '').toLowerCase().includes(termo) ||
        (cliente.cpf || '').toLowerCase().includes(termo)
      );
    }

    renderizarClientes(listaFiltrada, modoArquivadoClientes);
  }

  function renderizarClientes(listaClientes, modoArquivado = false) {
    if (!containerClientes) return;
    containerClientes.innerHTML = '';

    if (listaClientes.length === 0) {
      containerClientes.innerHTML = `<p style="color: var(--text-muted); padding: 20px;">${modoArquivado ? 'Nenhum cliente arquivado.' : 'Nenhum cliente encontrado.'}</p>`;
      return;
    }

    listaClientes.forEach(cliente => {
      const card = document.createElement('div');
      card.className = modoArquivado ? 'customer-card card-arquivado' : 'customer-card';

      const dropdownHtml = modoArquivado
        ? `<button class="card-dropdown-item reativar-btn" data-id="${cliente.id}"><i class="ri-arrow-go-back-line"></i> Reativar</button>`
        : `<button class="card-dropdown-item edit-btn" data-id="${cliente.id}"><i class="ri-edit-line"></i> Editar</button>
         <button class="card-dropdown-item delete-item archive-btn" data-id="${cliente.id}"><i class="ri-archive-line"></i> Arquivar</button>`;

      card.innerHTML = `
      <button class="btn-card-options"><i class="ri-more-2-fill"></i></button>
      <div class="card-dropdown">
        ${dropdownHtml}
      </div>
      <span class="status-badge status-disponivel"><i class="ri-checkbox-circle-line"></i> Cadastrado</span>
      <div class="vehicle-info">
        <h4>${cliente.nome}</h4>
        <p><i class="ri-phone-line"></i> ${cliente.telefone}</p>
      </div>
      <div class="customer-details">
        <div class="customer-data-entry"><span><strong>CPF:</strong> ${cliente.cpf}</span></div>
        <div class="customer-data-entry"><span><strong>CNH:</strong> ${cliente.cnh}</span></div>
      </div>
    `;

      const btnOptions = card.querySelector('.btn-card-options');
      const dropdown = card.querySelector('.card-dropdown');

      btnOptions.addEventListener('click', (e) => {
        e.stopPropagation();
        document.querySelectorAll('.card-dropdown').forEach(d => { if (d !== dropdown) d.classList.remove('show'); });
        dropdown.classList.toggle('show');
      });

      if (modoArquivado) {
        card.querySelector('.reativar-btn').addEventListener('click', async (e) => {
          e.stopPropagation();
          dropdown.classList.remove('show');
          await window.apiAcesso.reativarCliente(cliente.id);
        });
      } else {
        card.querySelector('.edit-btn').addEventListener('click', (e) => {
          e.stopPropagation();
          dropdown.classList.remove('show');
          localStorage.setItem('clienteParaEditar', JSON.stringify(cliente));
          window.apiAcesso.abrirModalCliente();
        });

        card.querySelector('.archive-btn').addEventListener('click', async (e) => {
          e.stopPropagation();
          dropdown.classList.remove('show');

          const confirmou = await window.apiAcesso.confirmar({
            titulo: "Arquivar Cliente",
            mensagem: "Quer mesmo arquivar este cliente? Ele será movido para os arquivados e não aparecerá mais nas listagens ativas. O histórico de locações será mantido, e você pode reativá-lo quando quiser.",
            textoConfirmar: "Arquivar",
            tipo: "perigo"
          });

          if (confirmou) {
            await window.apiAcesso.arquivarCliente(cliente.id);
          }
        });
      }

      aplicarPermissoesNoCard(card, {
        '.edit-btn': 'editar_clientes',
        '.archive-btn': 'arquivar_clientes',
        '.reativar-btn': 'arquivar_clientes'
      });
      containerClientes.appendChild(card);
    });
  }

  function renderizarLocacoesAtivas(listaLocacoes) {
    if (!tabelaLocacoesAtivasBody) return;
    tabelaLocacoesAtivasBody.innerHTML = '';

    if (listaLocacoes.length === 0) {
      tabelaLocacoesAtivasBody.innerHTML = `<tr><td colspan="7" style="text-align: center; color: var(--text-muted); padding: 20px;">Nenhuma locação em andamento no momento.</td></tr>`;
      return;
    }

    listaLocacoes.forEach(loc => {
      const valorFormatado = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(loc.valor_total);
      const tr = document.createElement('tr');

      tr.innerHTML = `
        <td><strong>${loc.clientes?.nome || 'Cliente não encontrado'}</strong></td>
        <td>${loc.veiculos?.modelo || 'Veículo não encontrado'} (${loc.veiculos?.placa || ''})</td>
        <td>${new Date(loc.data_inicio).toLocaleDateString('pt-BR', { timeZone: 'UTC' })}</td>
        <td>${new Date(loc.data_fim).toLocaleDateString('pt-BR', { timeZone: 'UTC' })}</td>
        <td><strong style="color: var(--blue-dark);">${valorFormatado}</strong></td>
        <td><span class="badge badge-green">${loc.status}</span></td>
        <td style="text-align: center;">
          <button class="btn-dar-baixa" data-id="${loc.id}" data-veiculo="${loc.id_veiculo}" style="padding: 6px 12px; background: #e74c3c; color: #fff; border: none; border-radius: 4px; cursor: pointer; font-weight: 600; font-size: 0.85rem; transition: background 0.2s;">
            <i class="ri-checkbox-circle-fill"></i> Finalizar
          </button>
        </td>
      `;
      tabelaLocacoesAtivasBody.appendChild(tr);
    });

    // Sem a permissão "finalizar_locacoes", o botão Finalizar nem aparece
    if (!tem('finalizar_locacoes')) {
      tabelaLocacoesAtivasBody.querySelectorAll('.btn-dar-baixa').forEach(b => b.remove());
    }

    tabelaLocacoesAtivasBody.querySelectorAll('.btn-dar-baixa').forEach(botao => {
      botao.addEventListener('click', async () => {
        const idLocacao = parseInt(botao.getAttribute('data-id'));
        const idVeiculo = parseInt(botao.getAttribute('data-veiculo'));

        const confirmou = await window.apiAcesso.confirmar({
          titulo: "Finalizar Contrato",
          mensagem: "Tem certeza que deseja encerrar esta locação e liberar o carro para a frota?",
          textoConfirmar: "Confirmar Devolução",
          tipo: "sucesso",
          tipoCancelar: "perigo"
        });

        if (!confirmou) return;

        try {
          botao.disabled = true;
          botao.textContent = "Processando...";
          const resultado = await window.apiAcesso.finalizarLocacao(idLocacao, idVeiculo);
          if (resultado && resultado.sucesso) {
            switchView('view-locacoes-ativas');
          } else {
            botao.disabled = false;
            botao.innerHTML = `<i class="ri-checkbox-circle-fill"></i> Finalizar`;
          }
        } catch (erro) {
          console.error("Erro ao finalizar locação:", erro);
          botao.disabled = false;
          botao.innerHTML = `<i class="ri-checkbox-circle-fill"></i> Finalizar`;
        }
      });
    });
  }

  function renderizarLocacoesHistorico(listaLocacoes) {
    if (!tabelaLocacoesHistoricoBody) return;
    tabelaLocacoesHistoricoBody.innerHTML = '';

    if (listaLocacoes.length === 0) {
      tabelaLocacoesHistoricoBody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: var(--text-muted); padding: 20px;">Nenhum histórico de locação encontrado.</td></tr>`;
      return;
    }

    listaLocacoes.forEach(loc => {
      const valorFormatado = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(loc.valor_total);
      const tr = document.createElement('tr');

      tr.innerHTML = `
        <td><strong>${loc.clientes?.nome || 'Cliente não encontrado'}</strong></td>
        <td><i class="ri-car-fill" style="color: #64748b; margin-right: 4px;"></i> ${loc.veiculos?.modelo || 'Veículo não encontrado'} (${loc.veiculos?.placa || ''})</td>
        <td>${new Date(loc.data_inicio).toLocaleDateString('pt-BR', { timeZone: 'UTC' })}</td>
        <td>${new Date(loc.data_fim).toLocaleDateString('pt-BR', { timeZone: 'UTC' })}</td>
        <td><span class="valor-historico">${valorFormatado}</span></td>
        <td><span class="badge-concluido"><i class="ri-checkbox-circle-line"></i> ${loc.status}</span></td>
      `;
      tabelaLocacoesHistoricoBody.appendChild(tr);
    });
  }

  function renderizarFinanceiro(dadosFinanceiros) {
    if (dadosFinanceiros && !dadosFinanceirosOriginais) {
      dadosFinanceirosOriginais = dadosFinanceiros;
    }

    const txtFaturamento = document.getElementById('fin-faturamento-total');
    const txtRecebimento = document.getElementById('fin-recebimento-projetado');
    const txtTicket = document.getElementById('fin-ticket-medio');
    const inputInicio = document.getElementById('fin-data-inicio');
    const inputFim = document.getElementById('fin-data-fim');

    const dadosParaProcessar = dadosFinanceirosOriginais || dadosFinanceiros;
    if (!dadosParaProcessar || !dadosParaProcessar.sucesso) return;

    const dataInicioFiltro = inputInicio && inputInicio.value ? new Date(inputInicio.value + 'T00:00:00Z') : null;
    const dataFimFiltro = inputFim && inputFim.value ? new Date(inputFim.value + 'T23:59:59Z') : null;

    let faturamentoFiltrado = 0;
    let totalContratosFiltrados = 0;
    let fluxoCaixaFiltrado = [];
    let recebimentoProjetado = dadosParaProcessar.financeiro?.recebimentoProjetado || 0;

    const listaFluxo = dadosParaProcessar.fluxoCaixa || [];
    listaFluxo.forEach(mov => {
      const dataMov = new Date(mov.data_fim);
      let passaNoFiltro = true;

      if (dataInicioFiltro && dataMov < dataInicioFiltro) passaNoFiltro = false;
      if (dataFimFiltro && dataMov > dataFimFiltro) passaNoFiltro = false;

      if (passaNoFiltro) {
        faturamentoFiltrado += parseFloat(mov.valor_total) || 0;
        totalContratosFiltrados++;
        fluxoCaixaFiltrado.push(mov);
      }
    });

    if (listaFluxo.length === 0 && dadosParaProcessar.financeiro) {
      faturamentoFiltrado = dadosParaProcessar.financeiro.faturamentoTotal;
      recebimentoProjetado = dadosParaProcessar.financeiro.recebimentoProjetado;
    }

    const ticketMedioFiltrado = totalContratosFiltrados > 0 ? (faturamentoFiltrado / totalContratosFiltrados) : (dadosParaProcessar.financeiro?.ticketMedio || 0);
    const formatador = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });

    if (txtFaturamento) txtFaturamento.textContent = formatador.format(faturamentoFiltrado);
    if (txtRecebimento) txtRecebimento.textContent = formatador.format(recebimentoProjetado);
    if (txtTicket) txtTicket.textContent = formatador.format(ticketMedioFiltrado);

    if (!tabelaFinanceiroBody) return;
    tabelaFinanceiroBody.innerHTML = '';

    if (fluxoCaixaFiltrado.length === 0) {
      tabelaFinanceiroBody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--text-muted); padding: 20px;">Nenhum registro financeiro encontrado para o período selecionado.</td></tr>`;
      return;
    }

    fluxoCaixaFiltrado.forEach(mov => {
      const valorMovFormatado = formatador.format(mov.valor_total);
      const dataFechamento = new Date(mov.data_fim).toLocaleDateString('pt-BR', { timeZone: 'UTC' });
      const tr = document.createElement('tr');

      tr.innerHTML = `
        <td><strong>${mov.clientes?.nome || 'Cliente Oculto'}</strong></td>
        <td><i class="ri-car-fill" style="color: #64748b; margin-right: 4px;"></i> ${mov.veiculos?.modelo || 'Veículo Desconhecido'}</td>
        <td>${dataFechamento}</td>
        <td><span style="color: #2ecc71; font-weight: 700;">+ ${valorMovFormatado}</span></td>
        <td><span class="badge-concluido" style="background: #e8f8f5; color: #1e8449; border-color: #d1f2eb;"><i class="ri-checkbox-circle-line"></i> Recebido</span></td>
      `;
      tabelaFinanceiroBody.appendChild(tr);
    });

    if (inputInicio && !inputInicio.dataset.listenerAtivo) {
      inputInicio.dataset.listenerAtivo = "true";
      inputInicio.addEventListener('change', () => renderizarFinanceiro());
      inputFim.addEventListener('change', () => renderizarFinanceiro());

      const btnLimpar = document.getElementById('btn-limpar-filtro-fin');
      if (btnLimpar) {
        btnLimpar.addEventListener('click', () => {
          inputInicio.value = '';
          inputFim.value = '';
          renderizarFinanceiro();
        });
      }
    }
  }

  const inputCpfCnpj = document.getElementById('cfg-cpf-cnpj');
  const inputTelefone = document.getElementById('cfg-telefone');

  if (inputCpfCnpj) {
    inputCpfCnpj.addEventListener('input', (e) => {
      let v = e.target.value.replace(/\D/g, '');
      if (v.length <= 11) {
        v = v.replace(/(\d{3})(\d)/, '$1.$2');
        v = v.replace(/(\d{3})(\d)/, '$1.$2');
        v = v.replace(/(\d{3})(\d{1,2})$/, '$1-$2');
      } else {
        v = v.substring(0, 14);
        v = v.replace(/^(\d{2})(\d)/, '$1.$2');
        v = v.replace(/^(\d{2})\.(\d{3})(\d)/, '$1.$2.$3');
        v = v.replace(/\.(\d{3})(\d)/, '.$1/$2');
        v = v.replace(/(\d{4})(\d)/, '$1-$2');
      }
      e.target.value = v;
    });
  }

  if (inputTelefone) {
    inputTelefone.addEventListener('input', (e) => {
      let v = e.target.value.replace(/\D/g, '').substring(0, 11);
      if (v.length > 10) {
        v = v.replace(/^(\d{2})(\d{5})(\d{4})$/, '($1) $2-$3');
      } else if (v.length > 5) {
        v = v.replace(/^(\d{2})(\d{4})(\d{0,4})$/, '($1) $2-$3');
      } else if (v.length > 2) {
        v = v.replace(/^(\d{2})(\d{0,5})$/, '($1) $2');
      }
      e.target.value = v;
    });
  }

  async function carregarDadosConfiguracoes() {
    try {
      if (window.apiAcesso && window.apiAcesso.pedirUsuarioLogado) {
        const usuario = await window.apiAcesso.pedirUsuarioLogado();
        if (!usuario) return;

        const elNome = document.getElementById('cfg-nome');
        const elCpf = document.getElementById('cfg-cpf-cnpj');
        const elTel = document.getElementById('cfg-telefone');
        const elEmail = document.getElementById('cfg-email');
        const elUser = document.getElementById('cfg-username');
        const elTema = document.getElementById('cfg-tema');

        if (elNome) elNome.value = usuario.nome || '';
        if (elCpf) elCpf.value = usuario.cpf_cnpj || '';
        if (elTel) elTel.value = usuario.telefone || '';
        if (elEmail) elEmail.value = usuario.email || '';
        if (elUser) elUser.value = usuario.username || usuario.nome || '';
        if (elTema) elTema.value = usuario.tema || 'Claro';

        const avatarInicial = document.getElementById('avatar-inicial');
        const avatarImg = document.getElementById('avatar-img');

        if (usuario.foto_url && avatarImg && avatarInicial) {
          avatarImg.src = usuario.foto_url;
          avatarImg.style.display = 'block';
          avatarInicial.style.display = 'none';
        } else if (avatarInicial) {
          avatarInicial.textContent = (usuario.nome || 'U').charAt(0).toUpperCase();
          if (avatarImg) avatarImg.style.display = 'none';
          avatarInicial.style.display = 'block';
        }

        const btnModalNovaSenha = document.getElementById('btn-modal-nova-senha');
        if (btnModalNovaSenha) {
          // onclick (e não addEventListener): evita registrar o clique de novo a cada visita à tela
          btnModalNovaSenha.onclick = () => {
            window.apiAcesso.abrirModalTrocarSenha();
          };
        }
      }
    } catch (err) {
      console.error("Erro ao carregar configurações:", err);
    }
  }

  async function switchView(targetId) {
    views.forEach(view => view.classList.remove('active'));

    const targetView = document.getElementById(targetId);
    if (targetView) {
      targetView.classList.add('active');

      if (pageTitle) {
        pageTitle.textContent = titulosPorView[targetId] || "Dashboard";
      }

      if (targetId === 'view-resumo') {
        carregarResumoDashboard();
      }

      if (targetId === 'view-frota') {
        try {
          modoArquivadoFrota = false;
          if (textoToggleArquivadosFrota) textoToggleArquivadosFrota.textContent = 'Arquivados';
          if (iconeToggleArquivadosFrota) iconeToggleArquivadosFrota.className = 'ri-archive-line';

          const dadosFrota = await window.apiAcesso.pedirFrota();
          listaFrotaAtual = dadosFrota;
          aplicarFiltrosFrota();
        } catch (erro) { console.error("Erro ao carregar frota:", erro); }
      }

      if (targetId === 'view-clientes') {
        try {
          modoArquivadoClientes = false;
          if (textoToggleArquivadosClientes) textoToggleArquivadosClientes.textContent = 'Arquivados';
          if (iconeToggleArquivadosClientes) iconeToggleArquivadosClientes.className = 'ri-archive-line';

          const dadosClientes = await window.apiAcesso.pedirClientes();
          listaClientesAtual = dadosClientes;
          aplicarFiltrosClientes();
        } catch (erro) { console.error("Erro ao carregar clientes:", erro); }
      }

      if (targetId === 'view-locacoes-ativas') {
        try {
          const dadosLocacoesAtivas = await window.apiAcesso.pedirLocacoesAtivas();
          renderizarLocacoesAtivas(dadosLocacoesAtivas);
        } catch (erro) { console.error("Erro ao carregar locações ativas:", erro); }
      }

      if (targetId === 'view-locacoes-historico') {
        try {
          const dadosHistorico = await window.apiAcesso.pedirLocacoesHistorico();
          renderizarLocacoesHistorico(dadosHistorico);
        } catch (erro) { console.error("Erro ao carregar histórico:", erro); }
      }

      if (targetId === 'view-financeiro') {
        try {
          dadosFinanceirosOriginais = null;
          const balancoFinanceiro = await window.apiAcesso.pedirDadosFinanceiros();
          renderizarFinanceiro(balancoFinanceiro);
        } catch (erro) { console.error("Erro ao carregar financeiro:", erro); }
      }

      if (targetId === 'view-configuracoes') {
        carregarDadosConfiguracoes();
      }

      if (targetId === 'view-colaboradores') {
        modoArquivadoColaboradores = false;
        if (textoToggleArquivadosColaboradores) textoToggleArquivadosColaboradores.textContent = 'Arquivados';
        if (iconeToggleArquivadosColaboradores) iconeToggleArquivadosColaboradores.className = 'ri-archive-line';
        carregarColaboradores();
      }

      if (targetId === 'view-grupos-permissao') {
        carregarGruposPermissao();
      }

      document.querySelectorAll('.menu-item').forEach(item => {
        item.classList.remove('active');
        if (item.getAttribute('data-target') === targetId) item.classList.add('active');
      });
    }
  }

  function renderizarColaboradores(listaColaboradores, modoArquivado = false) {
    if (!containerColaboradores) return;
    containerColaboradores.innerHTML = '';

    if (listaColaboradores.length === 0) {
      containerColaboradores.innerHTML = `<p style="color: var(--text-muted); padding: 20px;">${modoArquivado ? 'Nenhum colaborador arquivado.' : 'Nenhum colaborador cadastrado ainda.'}</p>`;
      return;
    }

    listaColaboradores.forEach(colaborador => {
      const nomeGrupo = colaborador.grupos_permissao?.nome || 'Sem grupo';

      const card = document.createElement('div');
      card.className = modoArquivado ? 'customer-card card-arquivado' : 'customer-card';

      const dropdownHtml = modoArquivado
        ? `<button class="card-dropdown-item reativar-btn" data-id="${colaborador.id}"><i class="ri-arrow-go-back-line"></i> Reativar</button>`
        : `<button class="card-dropdown-item edit-btn" data-id="${colaborador.id}"><i class="ri-edit-line"></i> Editar</button>
         <button class="card-dropdown-item redefinir-senha-btn" data-id="${colaborador.id}"><i class="ri-key-line"></i> Redefinir Senha</button>
         <button class="card-dropdown-item delete-item archive-btn" data-id="${colaborador.id}"><i class="ri-archive-line"></i> Arquivar</button>`;

      card.innerHTML = `
      <button class="btn-card-options"><i class="ri-more-2-fill"></i></button>
      <div class="card-dropdown">
        ${dropdownHtml}
      </div>
      <span class="badge-contagem">${nomeGrupo}</span>
      <div class="vehicle-info">
        <h4>${colaborador.nome || colaborador.username}</h4>
        <p>@${colaborador.username}</p>
      </div>
      <div class="customer-details">
        <div class="customer-data-entry"><span><strong>E-mail:</strong> ${colaborador.email || '-'}</span></div>
        <div class="customer-data-entry"><span><strong>Telefone:</strong> ${colaborador.telefone || '-'}</span></div>
      </div>
    `;

      const btnOptions = card.querySelector('.btn-card-options');
      const dropdown = card.querySelector('.card-dropdown');

      btnOptions.addEventListener('click', (e) => {
        e.stopPropagation();
        document.querySelectorAll('.card-dropdown').forEach(d => { if (d !== dropdown) d.classList.remove('show'); });
        dropdown.classList.toggle('show');
      });

      if (modoArquivado) {
        card.querySelector('.reativar-btn').addEventListener('click', async (e) => {
          e.stopPropagation();
          dropdown.classList.remove('show');
          await window.apiAcesso.reativarColaborador(colaborador.id);
        });
      } else {
        card.querySelector('.edit-btn').addEventListener('click', (e) => {
          e.stopPropagation();
          dropdown.classList.remove('show');
          // Entrega os dados do colaborador ao modal (mesmo padrão de veiculoParaEditar)
          localStorage.setItem('colaboradorParaEditar', JSON.stringify(colaborador));
          window.apiAcesso.abrirModalColaborador();
        });

        card.querySelector('.redefinir-senha-btn').addEventListener('click', (e) => {
          e.stopPropagation();
          dropdown.classList.remove('show');
          localStorage.setItem('colaboradorParaRedefinirSenha', JSON.stringify({
            id: colaborador.id,
            nome: colaborador.nome,
            username: colaborador.username
          }));
          window.apiAcesso.abrirModalRedefinirSenhaColaborador();
        });

        card.querySelector('.archive-btn').addEventListener('click', async (e) => {
          e.stopPropagation();
          dropdown.classList.remove('show');

          const confirmou = await window.apiAcesso.confirmar({
            titulo: "Arquivar Colaborador",
            mensagem: "Tem certeza que deseja arquivar este colaborador? O acesso dele ao sistema será bloqueado imediatamente, mas o histórico será preservado.",
            textoConfirmar: "Arquivar",
            tipo: "perigo"
          });

          if (confirmou) {
            await window.apiAcesso.arquivarColaborador(colaborador.id);
          }
        });
      }

      aplicarPermissoesNoCard(card, {
        '.edit-btn': 'editar_colaboradores',
        '.redefinir-senha-btn': 'editar_colaboradores',
        '.archive-btn': 'excluir_colaboradores',
        '.reativar-btn': 'excluir_colaboradores'
      });
      containerColaboradores.appendChild(card);
    });
  }

  function aplicarFiltrosColaboradores() {
    const termo = (inputBuscaColaboradores?.value || '').trim().toLowerCase();
    const listaBase = modoArquivadoColaboradores ? listaColaboradoresArquivadosAtual : listaColaboradoresAtual;
    let listaFiltrada = listaBase;

    if (termo) {
      listaFiltrada = listaFiltrada.filter(colab =>
        (colab.nome || '').toLowerCase().includes(termo) ||
        (colab.username || '').toLowerCase().includes(termo) ||
        (colab.email || '').toLowerCase().includes(termo)
      );
    }

    renderizarColaboradores(listaFiltrada, modoArquivadoColaboradores);
  }

  async function carregarColaboradores() {
    try {
      const colaboradores = await window.apiAcesso.pedirColaboradores();
      listaColaboradoresAtual = colaboradores;
      aplicarFiltrosColaboradores();
    } catch (erro) {
      console.error("Erro ao carregar colaboradores:", erro);
    }
  }

  if (inputBuscaColaboradores) {
    inputBuscaColaboradores.addEventListener('input', aplicarFiltrosColaboradores);
  }

  if (btnToggleArquivadosColaboradores) {
    btnToggleArquivadosColaboradores.addEventListener('click', async () => {
      modoArquivadoColaboradores = !modoArquivadoColaboradores;

      if (textoToggleArquivadosColaboradores) {
        textoToggleArquivadosColaboradores.textContent = modoArquivadoColaboradores ? 'Voltar para Ativos' : 'Arquivados';
      }
      if (iconeToggleArquivadosColaboradores) {
        iconeToggleArquivadosColaboradores.className = modoArquivadoColaboradores ? 'ri-arrow-left-line' : 'ri-archive-line';
      }

      if (modoArquivadoColaboradores) {
        try {
          listaColaboradoresArquivadosAtual = await window.apiAcesso.pedirColaboradoresArquivados();
        } catch (erro) {
          console.error("Erro ao carregar colaboradores arquivados:", erro);
        }
      }

      aplicarFiltrosColaboradores();
    });
  }

  if (btnAbrirCadastroColaborador) {
    btnAbrirCadastroColaborador.addEventListener('click', () => {
      localStorage.removeItem('colaboradorParaEditar');
      window.apiAcesso.abrirModalColaborador();
    });
  }

  function renderizarGruposPermissao(listaGrupos) {
    if (!containerGruposPermissao) return;
    containerGruposPermissao.innerHTML = '';

    if (listaGrupos.length === 0) {
      containerGruposPermissao.innerHTML = `<p style="color: var(--text-muted); padding: 20px;">Nenhum grupo de permissão criado ainda.</p>`;
      return;
    }

    listaGrupos.forEach(grupo => {
      const card = document.createElement('div');
      card.className = 'vehicle-card';

      card.innerHTML = `
      <button class="btn-card-options"><i class="ri-more-2-fill"></i></button>
      <div class="card-dropdown">
        <button class="card-dropdown-item ver-colaboradores-btn" data-id="${grupo.id}"><i class="ri-team-line"></i> Ver Colaboradores</button>
        <button class="card-dropdown-item edit-btn" data-id="${grupo.id}"><i class="ri-edit-line"></i> Editar</button>
        <button class="card-dropdown-item delete-item delete-btn" data-id="${grupo.id}"><i class="ri-delete-bin-line"></i> Excluir</button>
      </div>
      <span class="badge-contagem">${grupo.totalColaboradores} colaborador${grupo.totalColaboradores !== 1 ? 'es' : ''}</span>
      <div class="vehicle-info">
        <h4>${grupo.nome}</h4>
        <p style="text-transform: none; font-weight: 400;">${grupo.descricao || 'Sem descrição'}</p>
      </div>
    `;

      const btnOptions = card.querySelector('.btn-card-options');
      const dropdown = card.querySelector('.card-dropdown');

      btnOptions.addEventListener('click', (e) => {
        e.stopPropagation();
        document.querySelectorAll('.card-dropdown').forEach(d => { if (d !== dropdown) d.classList.remove('show'); });
        dropdown.classList.toggle('show');
      });

      card.querySelector('.ver-colaboradores-btn').addEventListener('click', (e) => {
        e.stopPropagation();
        dropdown.classList.remove('show');
        localStorage.setItem('grupoParaVerColaboradores', JSON.stringify({ id: grupo.id, nome: grupo.nome }));
        window.apiAcesso.abrirModalVerColaboradores();
      });

      card.querySelector('.edit-btn').addEventListener('click', (e) => {
        e.stopPropagation();
        dropdown.classList.remove('show');
        localStorage.setItem('grupoParaEditar', JSON.stringify(grupo));
        window.apiAcesso.abrirModalGrupo();
      });

      card.querySelector('.delete-btn').addEventListener('click', async (e) => {
        e.stopPropagation();
        dropdown.classList.remove('show');

        const confirmou = await window.apiAcesso.confirmar({
          titulo: "Excluir Grupo",
          mensagem: `Tem certeza que deseja excluir o grupo "${grupo.nome}"? Esta ação não pode ser desfeita.`,
          textoConfirmar: "Excluir",
          tipo: "perigo"
        });

        if (confirmou) {
          await window.apiAcesso.excluirGrupoPermissao(grupo.id);
        }
      });

      aplicarPermissoesNoCard(card, {
        '.ver-colaboradores-btn': 'ver_colaboradores',
        '.edit-btn': 'editar_colaboradores',
        '.delete-btn': 'excluir_colaboradores'
      });
      containerGruposPermissao.appendChild(card);
    });
  }

  if (window.apiAcesso && window.apiAcesso.aoAtualizarColaboradores) {
    window.apiAcesso.aoAtualizarColaboradores(() => {
      const viewColaboradores = document.getElementById('view-colaboradores');
      if (viewColaboradores && viewColaboradores.classList.contains('active')) {
        if (modoArquivadoColaboradores) {
          window.apiAcesso.pedirColaboradoresArquivados().then(lista => {
            listaColaboradoresArquivadosAtual = lista;
            aplicarFiltrosColaboradores();
          });
        } else {
          carregarColaboradores();
        }
      }
    });
  }

  async function carregarGruposPermissao() {
    try {
      const grupos = await window.apiAcesso.pedirGruposPermissao();
      renderizarGruposPermissao(grupos);
    } catch (erro) {
      console.error("Erro ao carregar grupos de permissão:", erro);
    }
  }

  menuItems.forEach(item => {
    item.addEventListener('click', (e) => {
      e.preventDefault();
      const target = item.getAttribute('data-target');
      if (target) {
        switchView(target);
        if (userDropdown) userDropdown.classList.remove('show');
      }
    });
  });

  const btnAbrirConfig = document.getElementById('btn-abrir-configuracoes');
  if (btnAbrirConfig) {
    btnAbrirConfig.addEventListener('click', (e) => {
      e.preventDefault();
      switchView('view-configuracoes');
      if (userDropdown) userDropdown.classList.remove('show');
    });
  }

  if (btnLocacoesMaster) {
    btnLocacoesMaster.addEventListener('click', (e) => {
      e.preventDefault();
      const estaEscondido = submenuLocacoes.style.display === 'none' || submenuLocacoes.style.display === '';
      if (estaEscondido) {
        submenuLocacoes.style.display = 'flex';
        arrowIcon.style.transform = 'rotate(180deg)';
      } else {
        submenuLocacoes.style.display = 'none';
        arrowIcon.style.transform = 'rotate(0deg)';
      }
    });
  }

  if (btnAdministracaoMaster) {
    btnAdministracaoMaster.addEventListener('click', (e) => {
      e.preventDefault();
      const estaEscondido = submenuAdministracao.style.display === 'none' || submenuAdministracao.style.display === '';
      if (estaEscondido) {
        submenuAdministracao.style.display = 'flex';
        arrowIconAdmin.style.transform = 'rotate(180deg)';
      } else {
        submenuAdministracao.style.display = 'none';
        arrowIconAdmin.style.transform = 'rotate(0deg)';
      }
    });
  }

  if (btnAbrirModal) {
    btnAbrirModal.addEventListener('click', () => {
      localStorage.removeItem('veiculoParaEditar');
      window.apiAcesso.abrirModalCadastro();
    });
  }

  if (btnAbrirModalCliente) {
    btnAbrirModalCliente.addEventListener('click', () => {
      localStorage.removeItem('clienteParaEditar');
      window.apiAcesso.abrirModalCliente();
    });
  }

  if (btnAbrirModalLocacao) btnAbrirModalLocacao.addEventListener('click', () => window.apiAcesso.abrirModalLocacao());

  const btnAbrirModalGrupo = document.getElementById('btn-abrir-cadastro-grupo');
  if (btnAbrirModalGrupo) {
    btnAbrirModalGrupo.addEventListener('click', () => {
      localStorage.removeItem('grupoParaEditar');
      window.apiAcesso.abrirModalGrupo();
    });
  }

  if (btnPerfil) {
    btnPerfil.addEventListener('click', (e) => {
      e.stopPropagation();
      userDropdown.classList.toggle('show');
      btnPerfil.classList.toggle('dropdown-aberto');
    });
  }

  document.addEventListener('click', () => {
    if (userDropdown) userDropdown.classList.remove('show');
    if (filtroStatusMenu) filtroStatusMenu.classList.remove('show');
    if (filtroStatusWrapper) filtroStatusWrapper.classList.remove('aberto');
    document.querySelectorAll('.card-dropdown').forEach(d => d.classList.remove('show'));
  });

  if (btnSair) {
    btnSair.addEventListener('click', async (e) => {
      e.preventDefault();
      if (userDropdown) userDropdown.classList.remove('show');

      const confirmou = await window.apiAcesso.confirmar({
        titulo: "Sair do Sistema",
        mensagem: "Tem certeza que deseja sair? Você precisará fazer login novamente para acessar o sistema.",
        textoConfirmar: "Sair",
        tipo: "perigo"
      });

      if (confirmou) {
        window.apiAcesso.fecharApp();
      }
    });
  }

  if (window.apiAcesso && window.apiAcesso.aoAtualizarFrota) {
    window.apiAcesso.aoAtualizarFrota(async () => {
      await carregarResumoDashboard();

      const viewFrota = document.getElementById('view-frota');
      if (viewFrota && viewFrota.classList.contains('active')) {
        try {
          if (modoArquivadoFrota) {
            listaFrotaArquivadaAtual = await window.apiAcesso.pedirFrotaArquivada();
          } else {
            listaFrotaAtual = await window.apiAcesso.pedirFrota();
          }
          aplicarFiltrosFrota();
        } catch (erro) {
          console.error("Erro ao atualizar lista de frota em tempo real:", erro);
        }
      }
    });
  }

  if (window.apiAcesso && window.apiAcesso.aoAtualizarClientes) {
    window.apiAcesso.aoAtualizarClientes(async () => {
      await carregarResumoDashboard();

      const viewClientes = document.getElementById('view-clientes');
      if (viewClientes && viewClientes.classList.contains('active')) {
        try {
          if (modoArquivadoClientes) {
            listaClientesArquivadosAtual = await window.apiAcesso.pedirClientesArquivados();
          } else {
            listaClientesAtual = await window.apiAcesso.pedirClientes();
          }
          aplicarFiltrosClientes();
        } catch (erro) {
          console.error("Erro ao atualizar lista de clientes em tempo real:", erro);
        }
      }
    });
  }

  if (window.apiAcesso && window.apiAcesso.aoAtualizarGrupos) {
    window.apiAcesso.aoAtualizarGrupos(() => {
      const viewGrupos = document.getElementById('view-grupos-permissao');
      if (viewGrupos && viewGrupos.classList.contains('active')) {
        carregarGruposPermissao();
      }
    });
  }

  carregarResumoDashboard();
  carregarUsuarioLogado();
});