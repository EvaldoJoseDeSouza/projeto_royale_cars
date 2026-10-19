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
    esconderSe(pegar('.menu-item[data-target="view-frota"]'), !tem('veiculos_ver'));
    esconderSe(pegar('.menu-item[data-target="view-clientes"]'), !tem('clientes_ver'));
    esconderSe(pegar('.menu-item[data-target="view-financeiro"]'), !tem('financeiro'));
    esconderSe(pegar('.menu-item[data-target="view-manutencao"]'), !tem('manutencoes'));
    const wrapLocacoes = document.getElementById('btn-locacoes-master')?.closest('.menu-dropdown-wrapper');
    esconderSe(wrapLocacoes, !tem('locacoes_ver'));
    const wrapAdmin = document.getElementById('btn-administracao-master')?.closest('.menu-dropdown-wrapper');
    esconderSe(wrapAdmin, !tem('administracao'));

    // Cards de resumo do Dashboard
    esconderSe(pegar('.stat-card[data-target="view-financeiro"]'), !tem('financeiro'));
    esconderSe(pegar('.stat-card[data-target="view-locacoes-ativas"]'), !tem('locacoes_ver'));
    esconderSe(pegar('.stat-card[data-target="view-clientes"]'), !tem('clientes_ver'));
    esconderSe(pegar('.stat-card[data-target="view-frota"]'), !tem('veiculos_ver'));

    // Botões de ação das telas
    esconderSe(btnAbrirModal, !tem('veiculos_gerenciar'));
    esconderSe(btnAbrirModalCliente, !tem('clientes_gerenciar'));
    esconderSe(btnAbrirModalLocacao, !tem('locacoes_gerenciar'));
    esconderSe(document.getElementById('btn-abrir-manutencao'), !tem('manutencoes'));
    esconderSe(btnAbrirCadastroColaborador, !tem('administracao'));
    esconderSe(btnAbrirModalGrupo, !tem('administracao'));

    // Botões "Arquivados"
    esconderSe(document.getElementById('btn-toggle-arquivados-frota'), !tem('veiculos_arquivar'));
    esconderSe(document.getElementById('btn-toggle-arquivados-clientes'), !tem('clientes_arquivar'));
    esconderSe(btnToggleDesativadosColaboradores, !tem('administracao'));
  }

  let listaColaboradoresAtual = [];
  let listaColaboradoresDesativadosAtual = [];
  let modoDesativadosColaboradores = false;

  const containerColaboradores = document.getElementById('container-colaboradores');
  const inputBuscaColaboradores = document.getElementById('busca-colaboradores');
  const btnToggleDesativadosColaboradores = document.getElementById('btn-toggle-desativados-colaboradores');
  const textoToggleDesativadosColaboradores = document.getElementById('texto-toggle-desativados-colaboradores');
  const iconeToggleDesativadosColaboradores = document.getElementById('icone-toggle-desativados-colaboradores');
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
    'view-manutencao': 'Manutenção',
    'view-clientes': 'Gestão de Clientes',
    'view-locacoes-ativas': 'Locações em Andamento',
    'view-locacoes-historico': 'Histórico de Locações',
    'view-financeiro': 'Financeiro',
    'view-configuracoes': 'Configurações da Conta',
    'view-colaboradores': 'Gerenciar Colaboradores',
    'view-grupos-permissao': 'Modelos de Permissão'
  };

  // ============================== DASHBOARD ==============================
  // Os números do topo vêm das visões do banco (main/ipc/painel.js) e das
  // listas de locações e clientes. Cada pessoa só vê o que tem permissão.
  async function carregarResumoDashboard() {
    try {
      const [resumo, locacoesAtivas, clientes] = await Promise.all([
        window.apiAcesso.pedirResumoPainel(),
        window.apiAcesso.pedirLocacoesAtivas(),
        window.apiAcesso.pedirClientes(),
      ]);

      // Faturamento do mês, comparado com o mês passado
      if (resumo.faturamento) {
        const { mes, anterior } = resumo.faturamento;
        dashFaturamento.textContent = formatarDinheiro(mes);
        if (anterior > 0) {
          const variacao = ((mes - anterior) / anterior) * 100;
          dashSublegenda.textContent = `${variacao >= 0 ? '↑' : '↓'} ${Math.abs(variacao).toFixed(0)}% em relação ao mês passado`;
          dashSublegenda.style.color = variacao >= 0 ? '#10b981' : '#ef4444';
        } else {
          dashSublegenda.textContent = 'Aluguéis devolvidos neste mês';
          dashSublegenda.style.color = '';
        }
      }

      // Locações: total e quantas estão atrasadas
      const atrasadas = locacoesAtivas.filter(loc => loc.status_exibicao === 'Atrasada').length;
      dashLocacoesAtivas.textContent = locacoesAtivas.length;
      const descLocacoes = document.getElementById('dash-locacoes-desc');
      descLocacoes.textContent = atrasadas > 0 ? `${atrasadas} atrasada(s)` : 'Nenhuma atrasada';
      descLocacoes.style.color = atrasadas > 0 ? '#ef4444' : '';

      dashClientesAtivos.textContent = clientes.length;

      // Frota: disponíveis de quantos, e onde estão os outros
      if (resumo.frota) {
        const f = resumo.frota;
        dashStatusFrota.textContent = f.disponiveis;
        document.getElementById('dash-frota-desc').textContent =
          `de ${f.total} · ${f.alugados} alugado(s) · ${f.em_manutencao} na oficina`;
      }

      renderizarAlertas(resumo.alertas);

      // Próximas devoluções: a lista já vem ordenada por data prevista
      tabelaUltimasLocacoesBody.innerHTML = '';
      if (locacoesAtivas.length === 0) {
        tabelaUltimasLocacoesBody.innerHTML = linhaVazia(4, 'Nenhuma locação em andamento no momento.');
        return;
      }
      locacoesAtivas.slice(0, 5).forEach(loc => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td><strong>${escaparHtml(loc.modelo)}</strong> (${formatarPlaca(loc.placa)})</td>
          <td>${escaparHtml(loc.cliente_nome)}</td>
          <td>${formatarData(loc.data_retirada)}</td>
          <td>${etiquetaSituacao(loc.status_exibicao, loc.dias_atraso_atual)}</td>
        `;
        tabelaUltimasLocacoesBody.appendChild(tr);
      });
    } catch (erro) {
      console.error("Erro ao montar o resumo do dashboard:", erro);
    }
  }

  // Cada tipo de alerta da visão vw_alertas: ícone, cor e para onde leva
  const TIPOS_DE_ALERTA = {
    atraso: { icone: 'ri-alarm-warning-line', classe: 'alerta-critico', rotulo: 'Atraso', tela: 'view-locacoes-ativas' },
    devolucao_proxima: { icone: 'ri-calendar-event-line', classe: 'alerta-aviso', rotulo: 'Devolução próxima', tela: 'view-locacoes-ativas' },
    manutencao: { icone: 'ri-tools-line', classe: 'alerta-aviso', rotulo: 'Na oficina', tela: 'view-manutencao' },
    cnh: { icone: 'ri-id-card-line', classe: 'alerta-aviso', rotulo: 'CNH', tela: 'view-clientes' },
    login_suspeito: { icone: 'ri-shield-keyhole-line', classe: 'alerta-critico', rotulo: 'Login suspeito', tela: null },
  };

  function renderizarAlertas(alertas) {
    const caixa = document.getElementById('lista-alertas');
    caixa.innerHTML = '';

    if (!alertas || alertas.length === 0) {
      caixa.innerHTML = '<p class="alertas-vazio"><i class="ri-checkbox-circle-line"></i> Tudo em dia. Nenhum alerta agora.</p>';
      return;
    }

    alertas.forEach(alerta => {
      const tipo = TIPOS_DE_ALERTA[alerta.tipo] || { icone: 'ri-information-line', classe: 'alerta-aviso', rotulo: alerta.tipo, tela: null };
      const item = document.createElement(tipo.tela ? 'button' : 'div');
      item.className = `alerta-item ${tipo.classe}`;
      // O texto vem do banco: escaparHtml para entrar como texto, nunca como HTML
      item.innerHTML = `
        <i class="${tipo.icone}"></i>
        <span class="alerta-rotulo">${tipo.rotulo}</span>
        <span class="alerta-titulo">${escaparHtml(alerta.titulo)}</span>
        <span class="alerta-detalhe">${escaparHtml(alerta.detalhe)}</span>
      `;
      // Sem a permissão de manutenção, o alerta "na oficina" leva para a Frota
      const tela = alerta.tipo === 'manutencao' && !tem('manutencoes') ? 'view-frota' : tipo.tela;
      if (tela) item.addEventListener('click', () => switchView(tela));
      caixa.appendChild(item);
    });
  }

  async function carregarUsuarioLogado() {
    try {
      if (!window.apiAcesso || !window.apiAcesso.pedirUsuarioLogado) return;

      const usuario = await window.apiAcesso.pedirUsuarioLogado();
      if (!usuario) return;

      ehAdministrador = usuario.cargo === 'chefe';
      permissoesUsuario = Array.isArray(usuario.permissoes) ? usuario.permissoes : [];
      aplicarPermissoesNaInterface();

      const nomeExibicao = usuario.nome || 'Usuário';

      const elEmailSidebar = document.getElementById('header-usuario-email');
      if (elEmailSidebar) elEmailSidebar.textContent = usuario.email || '';
      mostrarNomeNoCabecalho(nomeExibicao);
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

    // Cor da etiqueta de cada status. Os textos são EXATAMENTE os do banco
    // (tipo status_veiculo): "Em manutenção" com m minúsculo.
    const CLASSE_POR_STATUS = {
      'Disponível': 'status-disponivel',
      'Alugado': 'status-alugado',
      'Em manutenção': 'status-manutencao',
    };

    listaCarros.forEach(carro => {
      const classeStatus = CLASSE_POR_STATUS[carro.status] || 'status-disponivel';
      const card = document.createElement('div');
      card.className = modoArquivado ? 'vehicle-card card-arquivado' : 'vehicle-card';

      const dropdownHtml = modoArquivado
        ? `<button class="card-dropdown-item reativar-btn"><i class="ri-arrow-go-back-line"></i> Reativar</button>`
        : `<button class="card-dropdown-item edit-btn"><i class="ri-edit-line"></i> Editar</button>
         ${carro.status === 'Disponível' ? '<button class="card-dropdown-item oficina-btn"><i class="ri-tools-line"></i> Enviar para oficina</button>' : ''}
         <button class="card-dropdown-item delete-item archive-btn"><i class="ri-archive-line"></i> Arquivar</button>`;

      // formatarPlaca, formatarDinheiro, formatarKm e escaparHtml vêm de
      // compartilhado/formatos.js
      card.innerHTML = `
      <button class="btn-card-options"><i class="ri-more-2-fill"></i></button>
      <div class="card-dropdown">
        ${dropdownHtml}
      </div>
      <span class="status-badge ${classeStatus}">${escaparHtml(carro.status)}</span>
      <div class="vehicle-info">
        <h4>${escaparHtml(carro.modelo)}</h4>
        <p>${escaparHtml(carro.marca)} · ${carro.ano}</p>
      </div>
      <div class="vehicle-km"><i class="ri-dashboard-3-line"></i> ${formatarKm(carro.quilometragem)}</div>
      <div class="vehicle-details">
        <span class="vehicle-plate">${formatarPlaca(carro.placa)}</span>
        <span class="vehicle-price">${formatarDinheiro(carro.valor_diaria)}/dia</span>
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

        // Abre o modal da oficina já com este carro escolhido
        const oficina = card.querySelector('.oficina-btn');
        if (oficina) oficina.addEventListener('click', (e) => {
          e.stopPropagation();
          dropdown.classList.remove('show');
          localStorage.setItem('veiculoParaManutencao', JSON.stringify(carro));
          window.apiAcesso.abrirModalManutencao();
        });

        card.querySelector('.archive-btn').addEventListener('click', async (e) => {
          e.stopPropagation();
          dropdown.classList.remove('show');

          const confirmou = await window.apiAcesso.confirmar({
            titulo: "Arquivar Veículo",
            mensagem: `Arquivar o ${carro.marca} ${carro.modelo} (${formatarPlaca(carro.placa)})? Ele sai da frota, mas o histórico de locações fica guardado e dá para reativar quando quiser.`,
            textoConfirmar: "Arquivar",
            tipo: "perigo"
          });

          if (confirmou) {
            await window.apiAcesso.arquivarVeiculo(carro.id);
          }
        });
      }

      aplicarPermissoesNoCard(card, {
        '.edit-btn': 'veiculos_gerenciar',
        '.oficina-btn': 'manutencoes',
        '.archive-btn': 'veiculos_arquivar',
        '.reativar-btn': 'veiculos_arquivar'
      });
      containerFrota.appendChild(card);
    });
  }

  function aplicarFiltrosFrota() {
    const termo = (inputBuscaFrota?.value || '').trim().toLowerCase();
    const listaBase = modoArquivadoFrota ? listaFrotaArquivadaAtual : listaFrotaAtual;
    let listaFiltrada = listaBase;

    if (termo) {
      // A placa está guardada sem hífen: tiramos o hífen do que foi digitado
      const termoPlaca = termo.toUpperCase().replace(/[^A-Z0-9]/g, '');
      listaFiltrada = listaFiltrada.filter(carro =>
        (termoPlaca && (carro.placa || '').includes(termoPlaca)) ||
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
      // O CPF está guardado só com números: tiramos pontos e traço do
      // que foi digitado na busca para comparar igual com igual.
      const termoNumeros = soDigitos(termo);
      listaFiltrada = listaFiltrada.filter(cliente =>
        (cliente.nome || '').toLowerCase().includes(termo) ||
        (cliente.email || '').toLowerCase().includes(termo) ||
        (termoNumeros && (cliente.cpf || '').includes(termoNumeros))
      );
    }

    renderizarClientes(listaFiltrada, modoArquivadoClientes);
  }

  // Etiqueta da CNH no cartão: em dia (verde), vencendo (amarelo), vencida (vermelho)
  function etiquetaCnh(validade) {
    const dias = diasAte(validade); // diasAte vem de compartilhado/formatos.js
    if (dias < 0) return '<span class="status-badge status-alugado"><i class="ri-error-warning-line"></i> CNH vencida</span>';
    if (dias <= 30) return `<span class="status-badge status-manutencao"><i class="ri-time-line"></i> CNH vence em ${dias} dia(s)</span>`;
    return '<span class="status-badge status-disponivel"><i class="ri-checkbox-circle-line"></i> CNH em dia</span>';
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
      card.className = modoArquivado ? 'customer-card card-cliente card-arquivado' : 'customer-card card-cliente';

      const dropdownHtml = modoArquivado
        ? `<button class="card-dropdown-item reativar-btn"><i class="ri-arrow-go-back-line"></i> Reativar</button>`
        : `<button class="card-dropdown-item edit-btn"><i class="ri-edit-line"></i> Editar</button>
         <button class="card-dropdown-item delete-item archive-btn"><i class="ri-archive-line"></i> Arquivar</button>`;

      // O banco guarda só números; formatarCpf/formatarTelefone/formatarData
      // (de compartilhado/formatos.js) colocam a máscara só para mostrar.
      card.innerHTML = `
      <button class="btn-card-options"><i class="ri-more-2-fill"></i></button>
      <div class="card-dropdown">
        ${dropdownHtml}
      </div>
      ${etiquetaCnh(cliente.cnh_validade)}
      <div class="vehicle-info">
        <h4>${escaparHtml(cliente.nome)}</h4>
        <p><i class="ri-phone-line"></i> ${formatarTelefone(cliente.telefone)}</p>
      </div>
      <div class="customer-details">
        <div class="customer-data-entry"><span><strong>CPF:</strong> ${formatarCpf(cliente.cpf)}</span></div>
        <div class="customer-data-entry"><span><strong>CNH:</strong> ${escaparHtml(cliente.cnh)} (vale até ${formatarData(cliente.cnh_validade)})</span></div>
        <div class="customer-data-entry"><span><strong>E-mail:</strong> ${escaparHtml(cliente.email)}</span></div>
        ${cliente.endereco ? `<div class="customer-data-entry"><span><strong>Endereço:</strong> ${escaparHtml(cliente.endereco)}</span></div>` : ''}
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
            mensagem: `Arquivar ${cliente.nome}? Ele sai da lista de clientes, mas o histórico de locações fica guardado e dá para reativar quando quiser.`,
            textoConfirmar: "Arquivar",
            tipo: "perigo"
          });

          if (confirmou) {
            await window.apiAcesso.arquivarCliente(cliente.id);
          }
        });
      }

      aplicarPermissoesNoCard(card, {
        '.edit-btn': 'clientes_gerenciar',
        '.archive-btn': 'clientes_arquivar',
        '.reativar-btn': 'clientes_arquivar'
      });
      containerClientes.appendChild(card);
    });
  }

  // ============================== LOCAÇÕES ==============================
  // As listas vêm da visão vw_locacoes do banco: cliente_nome, marca,
  // modelo, placa e a situação de hoje (status_exibicao: "Em andamento",
  // "Atrasada", "Finalizada" ou "Cancelada").

  // Etiqueta colorida da situação do aluguel
  function etiquetaSituacao(situacao, diasAtraso) {
    const classes = {
      'Em andamento': 'status-disponivel',
      'Atrasada': 'status-alugado',
      'Finalizada': 'status-disponivel',
      'Cancelada': 'status-cancelada',
    };
    const texto = situacao === 'Atrasada' ? `Atrasada ${diasAtraso} dia(s)` : situacao;
    return `<span class="status-badge ${classes[situacao] || ''}">${escaparHtml(texto)}</span>`;
  }

  function linhaVazia(colunas, texto) {
    return `<tr><td colspan="${colunas}" style="text-align: center; color: var(--text-muted); padding: 20px;">${texto}</td></tr>`;
  }

  // O contrato só precisa do número do aluguel: o resto a janela busca
  function abrirContrato(locacaoId) {
    localStorage.setItem('locacaoParaContrato', String(locacaoId));
    window.apiAcesso.abrirModalContrato();
  }

  function renderizarLocacoesAtivas(listaLocacoes) {
    if (!tabelaLocacoesAtivasBody) return;
    tabelaLocacoesAtivasBody.innerHTML = '';

    if (listaLocacoes.length === 0) {
      tabelaLocacoesAtivasBody.innerHTML = linhaVazia(7, 'Nenhuma locação em andamento no momento.');
      return;
    }

    const podeDevolver = tem('locacoes_gerenciar');
    const podeCancelar = tem('locacoes_cancelar');

    listaLocacoes.forEach(loc => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td><strong>${escaparHtml(loc.cliente_nome)}</strong><br><small>${formatarTelefone(loc.cliente_telefone)}</small></td>
        <td>${escaparHtml(loc.marca)} ${escaparHtml(loc.modelo)}<br><small>${formatarPlaca(loc.placa)}</small></td>
        <td>${formatarData(loc.data_retirada)}</td>
        <td>${formatarData(loc.data_prevista)}</td>
        <td><strong style="color: var(--blue-dark);">${formatarDinheiro(loc.valor_previsto)}</strong></td>
        <td>${etiquetaSituacao(loc.status_exibicao, loc.dias_atraso_atual)}</td>
        <td class="acoes-locacao">
          <button class="btn-acao-tabela btn-contrato" title="Ver o contrato" aria-label="Ver o contrato"><i class="ri-file-text-line"></i></button>
          ${podeDevolver ? '<button class="btn-acao-tabela btn-devolver"><i class="ri-checkbox-circle-line"></i> Devolver</button>' : ''}
          ${podeCancelar ? '<button class="btn-acao-tabela btn-cancelar-locacao"><i class="ri-close-circle-line"></i> Cancelar</button>' : ''}
        </td>
      `;

      // Entrega os dados do aluguel ao modal (mesmo padrão dos outros modais)
      tr.querySelector('.btn-contrato').addEventListener('click', () => abrirContrato(loc.id));

      const devolver = tr.querySelector('.btn-devolver');
      if (devolver) devolver.addEventListener('click', () => {
        localStorage.setItem('locacaoParaDevolver', JSON.stringify(loc));
        window.apiAcesso.abrirModalDevolucao();
      });

      const cancelar = tr.querySelector('.btn-cancelar-locacao');
      if (cancelar) cancelar.addEventListener('click', () => {
        localStorage.setItem('locacaoParaCancelar', JSON.stringify(loc));
        window.apiAcesso.abrirModalCancelarLocacao();
      });

      tabelaLocacoesAtivasBody.appendChild(tr);
    });
  }

  function renderizarLocacoesHistorico(listaLocacoes) {
    if (!tabelaLocacoesHistoricoBody) return;
    tabelaLocacoesHistoricoBody.innerHTML = '';

    if (listaLocacoes.length === 0) {
      tabelaLocacoesHistoricoBody.innerHTML = linhaVazia(8, 'Nenhuma locação encerrada ainda.');
      return;
    }

    listaLocacoes.forEach(loc => {
      const cancelada = loc.status === 'Cancelada';

      // Detalhes do total: atraso e taxas aparecem embaixo do valor
      const detalhes = [
        loc.dias_atraso > 0 ? `${loc.dias_atraso} dia(s) de atraso` : '',
        Number(loc.taxas_extras) > 0 ? `taxas ${formatarDinheiro(loc.taxas_extras)} (${escaparHtml(loc.taxas_motivo)})` : '',
      ].filter(Boolean).join(' · ');

      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td><strong>${escaparHtml(loc.cliente_nome)}</strong></td>
        <td>${escaparHtml(loc.marca)} ${escaparHtml(loc.modelo)}<br><small>${formatarPlaca(loc.placa)}</small></td>
        <td>${formatarData(loc.data_retirada)}</td>
        <td>${cancelada ? '-' : formatarData(loc.data_devolucao)}</td>
        <td>${loc.km_rodados != null ? formatarKm(loc.km_rodados) : '-'}</td>
        <td><span class="valor-historico">${formatarDinheiro(loc.valor_total)}</span>${detalhes ? `<br><small>${detalhes}</small>` : ''}</td>
        <td>${etiquetaSituacao(loc.status)}</td>
        <td class="acoes-locacao">
          <button class="btn-acao-tabela btn-contrato" title="Ver o contrato"><i class="ri-file-text-line"></i> Contrato</button>
        </td>
      `;
      tr.querySelector('.btn-contrato').addEventListener('click', () => abrirContrato(loc.id));
      tabelaLocacoesHistoricoBody.appendChild(tr);
    });
  }

  // ============================== FINANCEIRO ==============================
  const inputFinInicio = document.getElementById('fin-data-inicio');
  const inputFinFim = document.getElementById('fin-data-fim');

  // Primeiro dia do mês de uma data "AAAA-MM-DD"
  const inicioDoMes = (data) => `${data.slice(0, 7)}-01`;

  // Botões de atalho do período
  function periodoDoBotao(qual) {
    const hoje = hojeTexto();
    if (qual === 'mes-passado') {
      const fimMesPassado = somarDias(inicioDoMes(hoje), -1); // dia anterior ao dia 1 = último dia do mês passado
      return { inicio: inicioDoMes(fimMesPassado), fim: fimMesPassado };
    }
    if (qual === 'ano') return { inicio: `${hoje.slice(0, 4)}-01-01`, fim: hoje };
    return { inicio: inicioDoMes(hoje), fim: hoje }; // "Este mês"
  }

  async function carregarFinanceiro(periodo) {
    if (periodo) {
      inputFinInicio.value = periodo.inicio;
      inputFinFim.value = periodo.fim;
    }
    const dados = await window.apiAcesso.pedirFinanceiro({ inicio: inputFinInicio.value, fim: inputFinFim.value });
    if (!dados || !dados.sucesso) return;

    inputFinInicio.value = dados.periodo.inicio;
    inputFinFim.value = dados.periodo.fim;
    renderizarFinanceiro(dados);
  }

  document.querySelectorAll('.btn-periodo').forEach(botao => {
    botao.addEventListener('click', () => carregarFinanceiro(periodoDoBotao(botao.dataset.periodo)));
  });
  [inputFinInicio, inputFinFim].forEach(campo => campo.addEventListener('change', () => carregarFinanceiro()));

  function renderizarFinanceiro(dados) {
    const ind = dados.indicadores;
    document.getElementById('fin-faturamento').textContent = formatarDinheiro(ind.faturamento);
    document.getElementById('fin-alugueis').textContent = `${ind.alugueis} aluguel(éis) finalizado(s)`;
    document.getElementById('fin-manutencao').textContent = formatarDinheiro(ind.gastoManutencao);
    const elResultado = document.getElementById('fin-resultado');
    elResultado.textContent = formatarDinheiro(ind.resultado);
    elResultado.style.color = ind.resultado < 0 ? '#ef4444' : '';
    document.getElementById('fin-ticket').textContent = formatarDinheiro(ind.ticketMedio);
    document.getElementById('fin-a-receber').textContent = formatarDinheiro(ind.aReceber);

    desenharGraficoMeses(dados.meses);

    // Entradas do período. Cliente/veículo podem vir vazios para quem só
    // tem a permissão Financeiro (ele não pode ver o cadastro de clientes).
    tabelaFinanceiroBody.innerHTML = '';
    if (dados.entradas.length === 0) {
      tabelaFinanceiroBody.innerHTML = linhaVazia(5, 'Nenhum aluguel finalizado neste período.');
      return;
    }
    dados.entradas.forEach(ent => {
      const extras = [
        ent.dias_atraso > 0 ? `${ent.dias_atraso} dia(s) de atraso` : '',
        Number(ent.taxas_extras) > 0 ? `inclui taxas de ${formatarDinheiro(ent.taxas_extras)}` : '',
      ].filter(Boolean).join(' · ');
      const carro = ent.veiculos ? `${escaparHtml(ent.veiculos.marca)} ${escaparHtml(ent.veiculos.modelo)} <small>${formatarPlaca(ent.veiculos.placa)}</small>` : '-';

      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>${formatarData(ent.data_devolucao)}</td>
        <td>#${ent.id}</td>
        <td>${ent.clientes ? escaparHtml(ent.clientes.nome) : '-'}</td>
        <td>${carro}</td>
        <td><strong class="valor-entrada">+ ${formatarDinheiro(ent.valor_total)}</strong>${extras ? `<br><small>${extras}</small>` : ''}</td>
      `;
      tabelaFinanceiroBody.appendChild(tr);
    });
  }

  // Gráfico de colunas dos 12 meses, feito só com HTML e CSS:
  // cada coluna é uma <div> com a altura em % do maior valor do gráfico.
  const NOMES_MESES = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

  function desenharGraficoMeses(meses) {
    const grafico = document.getElementById('grafico-meses');
    const dica = document.getElementById('grafico-dica');
    const corpoTabela = document.getElementById('tabela-meses-body');
    grafico.innerHTML = '';
    corpoTabela.innerHTML = '';

    // O maior valor vira 100% da altura (no mínimo 1, para não dividir por zero)
    const maior = Math.max(1, ...meses.map(m => Math.max(m.faturamento, m.manutencao)));
    const ultimo = meses.length - 1;

    // Linhas de grade: 0, metade e o máximo
    [1, 0.5, 0].forEach(fracao => {
      const linha = document.createElement('div');
      linha.className = 'grafico-grade';
      linha.style.bottom = `${fracao * 100}%`;
      linha.innerHTML = `<span>${formatarDinheiro(maior * fracao).replace(',00', '')}</span>`;
      grafico.appendChild(linha);
    });

    meses.forEach((m, i) => {
      const [ano, mes] = m.mes.split('-');
      const nomeMes = `${NOMES_MESES[Number(mes) - 1]}/${ano.slice(2)}`;

      const grupo = document.createElement('div');
      grupo.className = 'grafico-grupo';
      grupo.innerHTML = `
        <div class="grafico-barras">
          <div class="grafico-barra serie-faturamento" style="height:${(m.faturamento / maior) * 100}%">
            ${i === ultimo && m.faturamento > 0 ? `<span class="grafico-rotulo">${formatarDinheiro(m.faturamento).replace(',00', '')}</span>` : ''}
          </div>
          <div class="grafico-barra serie-manutencao" style="height:${(m.manutencao / maior) * 100}%"></div>
        </div>
        <span class="grafico-mes">${nomeMes}</span>
      `;

      // Passar o mouse no mês mostra os números exatos
      grupo.addEventListener('mouseenter', () => {
        dica.innerHTML = `<strong>${nomeMes}</strong> · ${m.alugueis} aluguel(éis)<br>
          <i class="legenda-cor serie-faturamento"></i> Faturamento: ${formatarDinheiro(m.faturamento)}<br>
          <i class="legenda-cor serie-manutencao"></i> Manutenção: ${formatarDinheiro(m.manutencao)}`;
        dica.hidden = false;
        const caixaGrafico = grafico.getBoundingClientRect();
        const caixaGrupo = grupo.getBoundingClientRect();
        const esquerda = caixaGrupo.left - caixaGrafico.left + caixaGrupo.width / 2;
        dica.style.left = `${Math.min(Math.max(esquerda, 90), caixaGrafico.width - 90)}px`;
      });
      grupo.addEventListener('mouseleave', () => { dica.hidden = true; });
      grafico.appendChild(grupo);

      // A mesma informação em tabela (para quem prefere ler os números)
      const tr = document.createElement('tr');
      tr.innerHTML = `<td>${nomeMes}</td><td>${m.alugueis}</td><td>${formatarDinheiro(m.faturamento)}</td><td>${formatarDinheiro(m.manutencao)}</td>`;
      corpoTabela.appendChild(tr);
    });
  }

  // ============================ MINHA CONTA ============================
  const NOMES_CARGOS = { chefe: 'Chefe', gerente: 'Gerente', funcionario: 'Funcionário' };

  // Mostra o nome no topo e no menu (usado ao entrar e depois de salvar)
  function mostrarNomeNoCabecalho(nome) {
    const elNomeSidebar = document.getElementById('header-usuario-nome');
    const elAvatarInicial = document.getElementById('header-avatar-inicial');
    const elNomeTopBar = document.getElementById('top-bar-usuario-nome');
    const elAvatarConta = document.getElementById('avatar-inicial');

    if (elNomeSidebar) elNomeSidebar.textContent = nome;
    if (elNomeTopBar) elNomeTopBar.textContent = nome;
    if (elAvatarInicial) elAvatarInicial.textContent = nome.charAt(0).toUpperCase();
    if (elAvatarConta) elAvatarConta.textContent = nome.charAt(0).toUpperCase();
  }

  // Monta as "etiquetas" com o que a pessoa pode fazer
  function mostrarPermissoes(usuario) {
    const caixa = document.getElementById('cfg-permissoes');
    if (!caixa) return;
    caixa.innerHTML = '';

    // O chefe não tem lista: ele pode tudo
    const lista = usuario.cargo === 'chefe'
      ? ['Acesso total (chefe)']
      : (usuario.permissoes || []).map(tituloDaPermissao); // vem de compartilhado/permissoes.js

    if (lista.length === 0) lista.push('Nenhuma permissão liberada ainda');

    lista.forEach((texto) => {
      const etiqueta = document.createElement('span');
      etiqueta.className = 'badge';
      etiqueta.textContent = texto; // textContent: o texto entra como texto, nunca como HTML
      caixa.appendChild(etiqueta);
    });
  }

  async function carregarDadosConfiguracoes() {
    try {
      const usuario = await window.apiAcesso.pedirUsuarioLogado();
      if (!usuario) return;

      document.getElementById('cfg-nome').value = usuario.nome || '';
      document.getElementById('cfg-email').value = usuario.email || '';
      document.getElementById('cfg-cargo').value = NOMES_CARGOS[usuario.cargo] || usuario.cargo || '';
      document.getElementById('avatar-inicial').textContent = (usuario.nome || 'U').charAt(0).toUpperCase();
      mostrarPermissoes(usuario);

      const btnModalNovaSenha = document.getElementById('btn-modal-nova-senha');
      if (btnModalNovaSenha) {
        // onclick (e não addEventListener): evita registrar o clique de novo a cada visita à tela
        btnModalNovaSenha.onclick = () => {
          window.apiAcesso.abrirModalTrocarSenha();
        };
      }
    } catch (err) {
      console.error("Erro ao carregar configurações:", err);
    }
  }

  // Botão Salvar da Minha conta: manda o nome novo para o processo principal
  const formConfigPerfil = document.getElementById('form-config-perfil');
  if (formConfigPerfil) {
    formConfigPerfil.addEventListener('submit', async (e) => {
      e.preventDefault();

      const btnSalvar = document.getElementById('btn-salvar-perfil');
      const nome = document.getElementById('cfg-nome').value;

      btnSalvar.disabled = true;
      try {
        // Se der errado, o processo principal já mostra o aviso com o motivo
        const resposta = await window.apiAcesso.salvarMinhaConta({ nome });
        if (resposta.sucesso) {
          document.getElementById('cfg-nome').value = resposta.usuario.nome;
          mostrarNomeNoCabecalho(resposta.usuario.nome);
        }
      } catch (erro) {
        console.error('Erro ao salvar minha conta:', erro);
      } finally {
        btnSalvar.disabled = false;
      }
    });
  }

  // ======================== SAÍDA POR INATIVIDADE ========================
  // Cada movimento do mouse, tecla, clique ou rolagem "zera o relógio".
  // Se passar MINUTOS_SEM_USO sem nada disso, o sistema sai sozinho.
  // (Para testar, troque para 1 e espere um minuto sem mexer.)
  const MINUTOS_SEM_USO = 30;
  let relogioInatividade = null;

  function zerarRelogioInatividade() {
    clearTimeout(relogioInatividade);
    relogioInatividade = setTimeout(() => {
      window.apiAcesso.sairPorInatividade();
    }, MINUTOS_SEM_USO * 60 * 1000);
  }

  ['mousemove', 'keydown', 'click', 'scroll'].forEach((tipoEvento) => {
    // passive: true avisa o navegador que só estamos "ouvindo", sem travar a rolagem
    document.addEventListener(tipoEvento, zerarRelogioInatividade, { passive: true });
  });
  zerarRelogioInatividade();

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

      if (targetId === 'view-manutencao') {
        carregarManutencoes();
      }

      if (targetId === 'view-financeiro') {
        try {
          await carregarFinanceiro(periodoDoBotao('mes'));
        } catch (erro) { console.error("Erro ao carregar financeiro:", erro); }
      }

      if (targetId === 'view-configuracoes') {
        carregarDadosConfiguracoes();
      }

      if (targetId === 'view-colaboradores') {
        modoDesativadosColaboradores = false;
        if (textoToggleDesativadosColaboradores) textoToggleDesativadosColaboradores.textContent = 'Desativados';
        if (iconeToggleDesativadosColaboradores) iconeToggleDesativadosColaboradores.className = 'ri-user-unfollow-line';
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

  // ============================== MANUTENÇÃO ==============================
  // Duas abas: "Na oficina" (manutenções em andamento) e "Concluídas"
  // (histórico). Os dados vêm de main/ipc/manutencoes.js.
  const containerManutencao = document.getElementById('container-manutencao');
  const resumoManutencao = document.getElementById('resumo-manutencao');
  let abaManutencao = 'oficina';

  // Os 4 itens da vistoria (os mesmos do modal, da web e do celular)
  const ITENS_VISTORIA = [
    { campo: 'motor_ok', nome: 'Motor' },
    { campo: 'freios_ok', nome: 'Freios' },
    { campo: 'pneus_ok', nome: 'Pneus' },
    { campo: 'oleo_ok', nome: 'Óleo' },
  ];

  // true = OK, false = com problema, null = não conferido.
  // Se ninguém fez a vistoria, não mostra nada.
  function checklistHtml(m) {
    if (ITENS_VISTORIA.every(({ campo }) => m[campo] === null || m[campo] === undefined)) return '';
    const itens = ITENS_VISTORIA.map(({ campo, nome }) => {
      if (m[campo] === true) return `<span class="item-vistoria ok">✔ ${nome}</span>`;
      if (m[campo] === false) return `<span class="item-vistoria problema">✖ ${nome}</span>`;
      return `<span class="item-vistoria">– ${nome}</span>`;
    });
    return `<div class="checklist-vistoria">${itens.join('')}</div>`;
  }

  function renderizarManutencoes(lista) {
    if (!containerManutencao) return;
    containerManutencao.innerHTML = '';
    const naOficina = abaManutencao === 'oficina';

    // Linha de resumo em cima dos cartões
    if (naOficina) {
      document.getElementById('contagem-oficina').textContent = lista.length ? `(${lista.length})` : '';
      resumoManutencao.textContent = lista.length
        ? `${lista.length} carro(s) na oficina agora, bloqueados para aluguel.`
        : '';
    } else {
      const total = lista.reduce((soma, m) => soma + Number(m.custo || 0), 0);
      resumoManutencao.textContent = lista.length
        ? `${lista.length} manutenção(ões) concluída(s), custo total de ${formatarDinheiro(total)}.`
        : '';
    }

    if (lista.length === 0) {
      containerManutencao.innerHTML = naOficina
        ? '<p style="color: var(--text-muted); padding: 20px;">Nenhum carro na oficina. 🎉</p>'
        : '<p style="color: var(--text-muted); padding: 20px;">Nenhuma manutenção concluída ainda.</p>';
      return;
    }

    const hoje = hojeTexto();
    lista.forEach(m => {
      const carro = m.veiculos || {};
      const card = document.createElement('div');
      card.className = 'vehicle-card';

      // Previsão já passou e o carro ainda está lá? Fica em vermelho.
      const vencida = naOficina && m.previsao_liberacao && m.previsao_liberacao < hoje;
      const linhaPrevisao = m.previsao_liberacao
        ? `<br><span class="${vencida ? 'vencida' : ''}">Previsão: ${formatarData(m.previsao_liberacao)}${vencida ? ' (atrasada)' : ''}</span>`
        : '';

      // Veio de uma devolução com defeito? Mostra de qual locação.
      const origem = m.locacao_id ? `<br>Veio da devolução da locação #${m.locacao_id}` : '';

      const datas = naOficina
        ? `Entrou em ${formatarData(m.data_entrada)} (${diasEntre(m.data_entrada, hoje)} dia(s))${linhaPrevisao}${origem}`
        : `${formatarData(m.data_entrada)} → ${formatarData(m.data_liberacao)}${origem}`;

      // Quem enviou e quem liberou (os nomes vêm do banco: escaparHtml)
      const pessoas = naOficina
        ? (m.abriu ? `Enviado por ${escaparHtml(m.abriu.nome)}` : '')
        : `${m.abriu ? escaparHtml(m.abriu.nome) : '?'} → ${m.concluiu ? escaparHtml(m.concluiu.nome) : '?'}`;

      card.innerHTML = `
        <span class="status-badge ${naOficina ? 'status-manutencao' : 'status-disponivel'}">${naOficina ? 'Na oficina' : 'Concluída'}</span>
        <div class="vehicle-info">
          <h4>${escaparHtml(carro.marca)} ${escaparHtml(carro.modelo)}</h4>
          <p>${formatarPlaca(carro.placa)}${m.oficina ? ` · ${escaparHtml(m.oficina)}` : ''}</p>
        </div>
        <div class="manutencao-defeito"><strong>Defeito:</strong> ${escaparHtml(m.defeito)}</div>
        ${naOficina ? '' : `<div class="manutencao-defeito"><strong>Serviço:</strong> ${escaparHtml(m.servico_realizado)}</div>`}
        <div class="manutencao-datas">${datas}${pessoas ? `<br>${pessoas}` : ''}</div>
        ${checklistHtml(m)}
        <div class="vehicle-details">
          ${naOficina
            ? '<button class="btn-liberar"><i class="ri-checkbox-circle-line"></i> Liberar</button>'
            : `<span class="vehicle-price">${formatarDinheiro(m.custo)}</span>`}
        </div>
      `;

      const btnLiberar = card.querySelector('.btn-liberar');
      if (btnLiberar) {
        // Mesmo jeito dos outros modais: deixa os dados no localStorage e abre
        btnLiberar.addEventListener('click', () => {
          localStorage.setItem('manutencaoParaLiberar', JSON.stringify(m));
          window.apiAcesso.abrirModalLiberarManutencao();
        });
      }

      containerManutencao.appendChild(card);
    });
  }

  async function carregarManutencoes() {
    try {
      const lista = await window.apiAcesso.pedirManutencoes(abaManutencao === 'oficina');
      renderizarManutencoes(lista || []);
    } catch (erro) {
      console.error('Erro ao carregar manutenções:', erro);
    }
  }

  // Troca de aba: pinta a escolhida e recarrega
  document.querySelectorAll('.aba-manutencao').forEach(botao => {
    botao.addEventListener('click', () => {
      document.querySelectorAll('.aba-manutencao').forEach(b => b.classList.remove('ativa'));
      botao.classList.add('ativa');
      abaManutencao = botao.dataset.aba;
      carregarManutencoes();
    });
  });

  // Botão "Enviar para a oficina" do topo: abre sem carro escolhido
  const btnAbrirManutencao = document.getElementById('btn-abrir-manutencao');
  if (btnAbrirManutencao) {
    btnAbrirManutencao.addEventListener('click', () => {
      localStorage.removeItem('veiculoParaManutencao');
      window.apiAcesso.abrirModalManutencao();
    });
  }

  // ============================ COLABORADORES ============================
  // escaparHtml vem de compartilhado/formatos.js

  const CARGOS = { chefe: 'Chefe', gerente: 'Gerente', funcionario: 'Funcionário' };

  function formatarUltimoAcesso(dataTexto) {
    if (!dataTexto) return 'Nunca entrou';
    return new Date(dataTexto).toLocaleString('pt-BR', {
      day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit'
    });
  }

  function renderizarColaboradores(lista, modoDesativados = false) {
    if (!containerColaboradores) return;
    containerColaboradores.innerHTML = '';

    if (lista.length === 0) {
      containerColaboradores.innerHTML = `<p style="color: var(--text-muted); padding: 20px;">${modoDesativados ? 'Ninguém desativado.' : 'Nenhum colaborador encontrado.'}</p>`;
      return;
    }

    // O chefe aparece primeiro; depois os outros em ordem de nome
    const ordenada = [...lista].sort((a, b) => (a.cargo === 'chefe' ? -1 : b.cargo === 'chefe' ? 1 : 0));

    ordenada.forEach((pessoa) => {
      const ehChefe = pessoa.cargo === 'chefe';
      const textoPermissoes = ehChefe
        ? 'Acesso total'
        : `${pessoa.permissoes.length} de ${TOTAL_PERMISSOES}`; // TOTAL_PERMISSOES vem de compartilhado/permissoes.js

      const card = document.createElement('div');
      card.className = modoDesativados ? 'customer-card card-colaborador card-desativado' : 'customer-card card-colaborador';

      // O chefe não tem menu: ninguém mexe no acesso dele por aqui
      const menuHtml = ehChefe ? '' : (modoDesativados
        ? `<button class="card-dropdown-item ativar-btn"><i class="ri-user-follow-line"></i> Ativar</button>`
        : `<button class="card-dropdown-item edit-btn"><i class="ri-edit-line"></i> Editar</button>
           <button class="card-dropdown-item redefinir-senha-btn"><i class="ri-key-line"></i> Redefinir Senha</button>
           <button class="card-dropdown-item delete-item desativar-btn"><i class="ri-user-unfollow-line"></i> Desativar</button>`);

      card.innerHTML = `
      ${menuHtml ? `<button class="btn-card-options"><i class="ri-more-2-fill"></i></button>
      <div class="card-dropdown">${menuHtml}</div>` : ''}
      <span class="badge-cargo cargo-${pessoa.cargo}">${CARGOS[pessoa.cargo] || pessoa.cargo}</span>
      <div class="vehicle-info">
        <h4>${escaparHtml(pessoa.nome)}</h4>
        <p>${escaparHtml(pessoa.email)}</p>
      </div>
      <div class="customer-details">
        <div class="customer-data-entry"><span><strong>Permissões:</strong> ${textoPermissoes}</span></div>
        <div class="customer-data-entry"><span><strong>Último acesso:</strong> ${formatarUltimoAcesso(pessoa.ultimo_acesso)}</span></div>
        ${pessoa.trocar_senha && !modoDesativados ? '<div class="aviso-troca-senha"><i class="ri-time-line"></i> Aguardando troca de senha</div>' : ''}
      </div>
    `;

      if (!ehChefe) ligarMenuDoColaborador(card, pessoa, modoDesativados);
      containerColaboradores.appendChild(card);
    });
  }

  // Liga os botões do menu "⋮" de um cartão
  function ligarMenuDoColaborador(card, pessoa, modoDesativados) {
    const dropdown = card.querySelector('.card-dropdown');
    const quem = { id: pessoa.id, nome: pessoa.nome };

    card.querySelector('.btn-card-options').addEventListener('click', (e) => {
      e.stopPropagation();
      document.querySelectorAll('.card-dropdown').forEach(d => { if (d !== dropdown) d.classList.remove('show'); });
      dropdown.classList.toggle('show');
    });

    // Atalho: fecha o menu e roda a ação
    function aoClicar(seletor, acao) {
      card.querySelector(seletor).addEventListener('click', async (e) => {
        e.stopPropagation();
        dropdown.classList.remove('show');
        await acao();
      });
    }

    if (modoDesativados) {
      aoClicar('.ativar-btn', async () => {
        const confirmou = await window.apiAcesso.confirmar({
          titulo: 'Ativar acesso',
          mensagem: `Devolver o acesso de ${pessoa.nome} ao sistema?`,
          textoConfirmar: 'Ativar',
          tipo: 'sucesso'
        });
        if (confirmou) await window.apiAcesso.ativarColaborador(quem);
      });
      return;
    }

    aoClicar('.edit-btn', () => {
      // Entrega os dados ao modal (mesmo padrão de veiculoParaEditar)
      localStorage.setItem('colaboradorParaEditar', JSON.stringify(pessoa));
      window.apiAcesso.abrirModalColaborador();
    });

    aoClicar('.redefinir-senha-btn', async () => {
      const confirmou = await window.apiAcesso.confirmar({
        titulo: 'Redefinir senha',
        mensagem: `Gerar uma nova senha temporária para ${pessoa.nome}? A senha atual deixa de funcionar.`,
        textoConfirmar: 'Gerar senha',
        tipo: 'perigo'
      });
      if (confirmou) await window.apiAcesso.redefinirSenhaColaborador(quem);
    });

    aoClicar('.desativar-btn', async () => {
      const confirmou = await window.apiAcesso.confirmar({
        titulo: 'Desativar acesso',
        mensagem: `Desativar o acesso de ${pessoa.nome}? Ele não consegue mais entrar no sistema, mas todo o histórico fica guardado.`,
        textoConfirmar: 'Desativar',
        tipo: 'perigo'
      });
      if (confirmou) await window.apiAcesso.desativarColaborador(quem);
    });
  }

  function aplicarFiltrosColaboradores() {
    const termo = (inputBuscaColaboradores?.value || '').trim().toLowerCase();
    const listaBase = modoDesativadosColaboradores ? listaColaboradoresDesativadosAtual : listaColaboradoresAtual;

    const listaFiltrada = !termo ? listaBase : listaBase.filter(pessoa =>
      (pessoa.nome || '').toLowerCase().includes(termo) ||
      (pessoa.email || '').toLowerCase().includes(termo)
    );

    renderizarColaboradores(listaFiltrada, modoDesativadosColaboradores);
  }

  // Busca a lista certa (ativos ou desativados) e redesenha
  async function carregarColaboradores() {
    try {
      if (modoDesativadosColaboradores) {
        listaColaboradoresDesativadosAtual = await window.apiAcesso.pedirColaboradoresDesativados();
      } else {
        listaColaboradoresAtual = await window.apiAcesso.pedirColaboradores();
      }
      aplicarFiltrosColaboradores();
    } catch (erro) {
      console.error("Erro ao carregar colaboradores:", erro);
    }
  }

  if (inputBuscaColaboradores) {
    inputBuscaColaboradores.addEventListener('input', aplicarFiltrosColaboradores);
  }

  if (btnToggleDesativadosColaboradores) {
    btnToggleDesativadosColaboradores.addEventListener('click', () => {
      modoDesativadosColaboradores = !modoDesativadosColaboradores;

      textoToggleDesativadosColaboradores.textContent = modoDesativadosColaboradores ? 'Voltar para Ativos' : 'Desativados';
      iconeToggleDesativadosColaboradores.className = modoDesativadosColaboradores ? 'ri-arrow-left-line' : 'ri-user-unfollow-line';

      carregarColaboradores();
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
      containerGruposPermissao.innerHTML = `<p style="color: var(--text-muted); padding: 20px;">Nenhum modelo de permissão criado ainda.</p>`;
      return;
    }

    listaGrupos.forEach(grupo => {
      const card = document.createElement('div');
      card.className = 'vehicle-card';

      card.innerHTML = `
      <button class="btn-card-options"><i class="ri-more-2-fill"></i></button>
      <div class="card-dropdown">
        <button class="card-dropdown-item edit-btn" data-id="${grupo.id}"><i class="ri-edit-line"></i> Editar</button>
        <button class="card-dropdown-item delete-item delete-btn" data-id="${grupo.id}"><i class="ri-delete-bin-line"></i> Excluir</button>
      </div>
      <span class="badge-contagem">${(grupo.permissoes || []).length} permiss${(grupo.permissoes || []).length !== 1 ? 'ões' : 'ão'}</span>
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
          titulo: "Excluir Modelo",
          mensagem: `Excluir o modelo "${grupo.nome}"? As permissões de quem já foi cadastrado com ele não mudam.`,
          textoConfirmar: "Excluir",
          tipo: "perigo"
        });

        if (confirmou) {
          await window.apiAcesso.excluirGrupoPermissao(grupo.id);
        }
      });

      aplicarPermissoesNoCard(card, {
        '.edit-btn': 'administracao',
        '.delete-btn': 'administracao'
      });
      containerGruposPermissao.appendChild(card);
    });
  }

  if (window.apiAcesso && window.apiAcesso.aoAtualizarColaboradores) {
    window.apiAcesso.aoAtualizarColaboradores(() => {
      // Só recarrega se a tela de colaboradores estiver aberta
      const viewColaboradores = document.getElementById('view-colaboradores');
      if (viewColaboradores && viewColaboradores.classList.contains('active')) {
        carregarColaboradores();
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

  // Locações mudaram (retirada, devolução ou cancelamento em outra janela):
  // recarrega a tabela que estiver aberta. O resumo já é recarregado pelo
  // aviso "frota-atualizada", que chega junto.
  if (window.apiAcesso && window.apiAcesso.aoAtualizarLocacoes) {
    window.apiAcesso.aoAtualizarLocacoes(async () => {
      try {
        if (document.getElementById('view-locacoes-ativas')?.classList.contains('active')) {
          renderizarLocacoesAtivas(await window.apiAcesso.pedirLocacoesAtivas());
        }
        if (document.getElementById('view-locacoes-historico')?.classList.contains('active')) {
          renderizarLocacoesHistorico(await window.apiAcesso.pedirLocacoesHistorico());
        }
      } catch (erro) {
        console.error("Erro ao atualizar as locações:", erro);
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

  // Alguém enviou ou liberou um carro (aqui ou em outra janela)
  if (window.apiAcesso && window.apiAcesso.aoAtualizarManutencoes) {
    window.apiAcesso.aoAtualizarManutencoes(() => {
      if (document.getElementById('view-manutencao')?.classList.contains('active')) {
        carregarManutencoes();
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