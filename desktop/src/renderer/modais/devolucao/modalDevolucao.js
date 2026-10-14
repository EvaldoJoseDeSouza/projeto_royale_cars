// =====================================================================
//  Modal de devolução
// ---------------------------------------------------------------------
//  A conta que aparece aqui é uma PRÉVIA, com as mesmas regras da função
//  registrar_devolucao do banco (quem grava e calcula de verdade):
//
//    diárias  = dias usados (devolução - retirada), no mínimo 1
//    atraso   = dias depois da data prevista (já estão dentro das diárias)
//    total    = diárias + taxas extras
//
//  Devolveu antes? Cobra só os dias usados (decisão do grupo).
//  Voltou com defeito? O carro vai direto para a manutenção.
//
//  Os dados do aluguel chegam pelo localStorage ("locacaoParaDevolver"),
//  deixados pelo dashboard ao clicar em "Devolver".
// =====================================================================

document.addEventListener('DOMContentLoaded', () => {
  const form = document.getElementById('form-devolucao');
  const btnSalvar = document.getElementById('btn-salvar');

  const campos = {
    data_devolucao: document.getElementById('data-devolucao'),
    km_retorno: document.getElementById('km-retorno'),
    taxas_extras: document.getElementById('taxas-extras'),
    taxas_motivo: document.getElementById('taxas-motivo'),
    observacoes: document.getElementById('observacoes'),
    com_defeito: document.getElementById('com-defeito'),
    defeito: document.getElementById('defeito'),
    oficina: document.getElementById('oficina'),
  };

  function fechar() {
    window.apiAcesso.fecharModalDevolucao();
  }
  document.getElementById('btn-cancelar').addEventListener('click', fechar);
  document.getElementById('btn-fechar-topo').addEventListener('click', fechar);

  // ------------------------------------------- QUAL ALUGUEL É ESTE?
  let locacao = null;
  try {
    locacao = JSON.parse(localStorage.getItem('locacaoParaDevolver'));
  } catch (e) {
    locacao = null;
  }
  localStorage.removeItem('locacaoParaDevolver'); // usou, apagou

  if (!locacao) {
    document.getElementById('ficha-locacao').textContent = 'Aluguel não encontrado. Feche e tente de novo.';
    btnSalvar.disabled = true;
    return;
  }

  // Ficha do aluguel. Montada com textContent: nome e carro vêm do banco.
  const ficha = document.getElementById('ficha-locacao');
  [
    `Aluguel #${locacao.id} · ${locacao.cliente_nome}`,
    `${locacao.marca} ${locacao.modelo} (${formatarPlaca(locacao.placa)})`,
    `Retirada ${formatarData(locacao.data_retirada)} · previsto ${formatarData(locacao.data_prevista)} · ${formatarDinheiro(locacao.valor_diaria)}/dia`,
  ].forEach((texto) => {
    const linha = document.createElement('div');
    linha.textContent = texto;
    ficha.appendChild(linha);
  });

  // ------------------------------------------------ VALORES INICIAIS
  const hoje = hojeTexto();
  campos.data_devolucao.value = hoje;
  campos.data_devolucao.min = locacao.data_retirada; // não pode ser antes da retirada
  campos.data_devolucao.max = hoje;                  // nem no futuro

  const kmSaida = Number(locacao.km_saida || 0);
  document.getElementById('dica-km').textContent = `Saiu com ${formatarKm(kmSaida)}. Não pode ser menor.`;

  const mascaraKm = (v) => {
    const n = soDigitos(v).slice(0, 7);
    return n ? Number(n).toLocaleString('pt-BR') : '';
  };
  aplicarMascara(campos.km_retorno, mascaraKm);
  aplicarMascara(campos.taxas_extras, mascaraDinheiro);

  // Mostra ou esconde os campos do defeito
  campos.com_defeito.addEventListener('change', () => {
    document.getElementById('bloco-defeito').style.display = campos.com_defeito.checked ? 'block' : 'none';
  });

  // --------------------------------------------------------- PRÉVIA
  function mostrar(idLinha, visivel) {
    document.getElementById(idLinha).style.display = visivel ? 'flex' : 'none';
  }

  function atualizarResumo() {
    const devolucao = campos.data_devolucao.value;
    if (!devolucao) return;

    const diaria = Number(locacao.valor_diaria);
    const dias = Math.max(1, diasEntre(locacao.data_retirada, devolucao));
    const atraso = Math.max(0, diasEntre(locacao.data_prevista, devolucao));
    const taxas = Number(soDigitos(campos.taxas_extras.value) || 0) / 100;
    const kmRetorno = Number(soDigitos(campos.km_retorno.value) || 0);

    document.getElementById('resumo-dias-texto').textContent = `${dias} diária(s) × ${formatarDinheiro(diaria)}:`;
    document.getElementById('resumo-diarias').textContent = formatarDinheiro(dias * diaria);

    mostrar('linha-atraso', atraso > 0);
    document.getElementById('resumo-atraso').textContent = `${atraso} dia(s) a mais (já somados)`;

    mostrar('linha-taxas', taxas > 0);
    document.getElementById('resumo-taxas').textContent = formatarDinheiro(taxas);

    mostrar('linha-km', kmRetorno >= kmSaida && kmRetorno > 0);
    document.getElementById('resumo-km').textContent = formatarKm(kmRetorno - kmSaida);

    document.getElementById('resumo-total').textContent = formatarDinheiro(dias * diaria + taxas);
    document.getElementById('dica-adiantada').style.display = devolucao < locacao.data_prevista ? 'block' : 'none';
  }

  ['input', 'change'].forEach((tipo) => form.addEventListener(tipo, atualizarResumo));
  atualizarResumo();

  // ------------------------------------------------------- SALVAR
  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const dados = { locacao_id: locacao.id };
    Object.keys(campos).forEach((chave) => {
      dados[chave] = campos[chave].type === 'checkbox' ? campos[chave].checked : campos[chave].value;
    });

    btnSalvar.disabled = true;
    try {
      const resposta = await window.apiAcesso.registrarDevolucao(dados);
      if (resposta && resposta.sucesso) fechar();
    } catch (erro) {
      console.error('Erro ao registrar devolução:', erro);
    } finally {
      btnSalvar.disabled = false;
    }
  });
});
