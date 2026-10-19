// =====================================================================
//  Modal "Contrato de locação"
// ---------------------------------------------------------------------
//  Mostra o contrato de um aluguel, com a assinatura que o cliente fez
//  no celular, e deixa imprimir ou salvar em PDF.
//
//  O número do aluguel chega pelo localStorage ("locacaoParaContrato"),
//  deixado pela tela de Locações. Os dados vêm de main/ipc/contratos.js.
//
//  O texto do contrato é o MESMO do PDF do celular, para o cliente
//  receber o mesmo documento, venha de onde vier.
// =====================================================================

document.addEventListener('DOMContentLoaded', async () => {
  const folha = document.getElementById('folha');
  const btnImprimir = document.getElementById('btn-imprimir');
  const btnPdf = document.getElementById('btn-pdf');

  function fechar() {
    window.apiAcesso.fecharModalContrato();
  }
  document.getElementById('btn-fechar').addEventListener('click', fechar);
  document.getElementById('btn-fechar-topo').addEventListener('click', fechar);

  function mostrarErro(mensagem) {
    folha.innerHTML = `<p class="folha-carregando">${escaparHtml(mensagem)}</p>`;
  }

  // ------------------------------------------- QUAL ALUGUEL É ESTE?
  const locacaoId = Number(localStorage.getItem('locacaoParaContrato'));
  localStorage.removeItem('locacaoParaContrato'); // usou, apagou
  if (!locacaoId) return mostrarErro('Aluguel não encontrado. Feche e tente de novo.');

  let resposta;
  try {
    resposta = await window.apiAcesso.pedirContrato(locacaoId);
  } catch (erro) {
    console.error('Erro ao carregar o contrato:', erro);
    resposta = { erro: 'Não foi possível carregar o contrato.' };
  }
  if (!resposta || resposta.erro) return mostrarErro(resposta ? resposta.erro : 'Não foi possível carregar o contrato.');

  const l = resposta.locacao;

  // ------------------------------------------------- PEÇAS DO TEXTO
  // Toda informação do banco passa pelo escaparHtml: entra como texto.
  const linha = (rotulo, valor, classe = '') =>
    `<div class="linha ${classe}"><span>${rotulo}:</span><strong>${escaparHtml(valor)}</strong></div>`;

  const secao = (titulo, conteudo) => `<div class="secao"><h4>${titulo}</h4>${conteudo}</div>`;

  // Data e hora (ex.: assinada_em) no jeito brasileiro: 19/10/2026 14:35
  const dataHora = (valor) =>
    valor ? new Date(valor).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }) : '-';

  const km = (valor) => (valor === null || valor === undefined ? '-' : formatarKm(valor));
  const cancelada = l.status === 'Cancelada';
  const finalizada = l.status === 'Finalizada';

  // ------------------------------------------------- AS SEÇÕES
  const cliente = secao('DADOS DO CLIENTE', [
    linha('Nome', l.cliente_nome),
    linha('CPF', formatarCpf(l.cliente_cpf)),
    linha('CNH', l.cliente_cnh),
    linha('Telefone', formatarTelefone(l.cliente_telefone)),
    l.cliente_email ? linha('E-mail', l.cliente_email) : '',
    l.cliente_endereco ? linha('Endereço', l.cliente_endereco) : '',
  ].join(''));

  const veiculo = secao('DADOS DO VEÍCULO', [
    linha('Veículo', `${l.marca} ${l.modelo}${l.ano ? ' ' + l.ano : ''}`),
    linha('Placa', formatarPlaca(l.placa)),
    linha('Quilometragem na retirada', km(l.km_saida)),
  ].join(''));

  const condicoes = secao('CONDIÇÕES DA LOCAÇÃO', [
    linha('Data de retirada', formatarData(l.data_retirada)),
    linha('Devolução prevista', formatarData(l.data_prevista)),
    linha('Diária combinada', formatarDinheiro(l.valor_diaria)),
    linha('Valor previsto', `${formatarDinheiro(l.valor_previsto)} (${l.dias_previstos} diária(s))`),
    l.registrado_por ? linha('Atendente', l.registrado_por) : '',
  ].join(''));

  // Depois da devolução, o contrato mostra o fechamento da conta
  const fechamento = !finalizada ? '' : secao('FECHAMENTO', [
    linha('Data da devolução', formatarData(l.data_devolucao)),
    l.km_retorno !== null ? linha('Quilometragem na devolução', `${km(l.km_retorno)} (${km(l.km_rodados)} rodados)`) : '',
    l.dias_atraso > 0 ? linha('Atraso', `${l.dias_atraso} dia(s): ${formatarDinheiro(l.valor_atraso)}`) : '',
    Number(l.taxas_extras) > 0 ? linha('Taxas extras', `${formatarDinheiro(l.taxas_extras)} (${l.taxas_motivo || ''})`) : '',
    linha('Valor total', formatarDinheiro(l.valor_total), 'total'),
  ].join(''));

  const observacoes = l.observacoes ? secao('OBSERVAÇÕES', `<p style="white-space: pre-line;">${escaparHtml(l.observacoes)}</p>`) : '';

  // Com assinatura: a imagem. Sem assinatura: a linha para assinar no papel.
  const assinatura = resposta.assinatura
    ? `<img src="${resposta.assinatura}" alt="Assinatura do cliente">
       <p class="assinatura-nota">Assinado no celular em ${escaparHtml(dataHora(l.assinada_em))}.</p>`
    : `<div class="assinatura-linha"></div>
       ${l.assinatura_path ? '<p class="assinatura-nota">A imagem da assinatura não pôde ser carregada.</p>' : ''}`;

  // ------------------------------------------------- A FOLHA
  folha.innerHTML = `
    <div class="contrato-titulo">CONTRATO DE LOCAÇÃO DE VEÍCULO Nº ${l.id}</div>
    <div class="contrato-empresa">Royale Cars</div>
    <div class="contrato-emitido">Emitido em ${escaparHtml(dataHora(new Date()))}</div>
    ${cancelada ? '<div class="contrato-aviso cancelado">CONTRATO CANCELADO (sem cobrança)</div>' : ''}
    ${cliente}
    ${veiculo}
    ${condicoes}
    ${fechamento}
    ${observacoes}
    <p class="clausula">
      O(A) locatário(a) acima identificado(a) declara estar de acordo com os termos
      desta locação, comprometendo-se a devolver o veículo nas condições em que o
      recebeu, na data prevista, e a ressarcir a locadora por quaisquer avarias
      causadas durante o período de uso. Cada dia além da data prevista é cobrado
      pela diária combinada.
    </p>
    <div class="assinatura-area">
      <p>Assinatura do cliente:</p>
      ${assinatura}
      <p class="assinatura-nome">${escaparHtml(l.cliente_nome)}</p>
    </div>
  `;

  // ------------------------------------------------- BOTÕES
  btnImprimir.disabled = false;
  btnPdf.disabled = false;

  btnImprimir.addEventListener('click', async () => {
    btnImprimir.disabled = true;
    try {
      await window.apiAcesso.imprimirContrato();
    } finally {
      btnImprimir.disabled = false;
    }
  });

  btnPdf.addEventListener('click', async () => {
    btnPdf.disabled = true;
    try {
      await window.apiAcesso.salvarContratoPdf(l.id);
    } finally {
      btnPdf.disabled = false;
    }
  });
});
