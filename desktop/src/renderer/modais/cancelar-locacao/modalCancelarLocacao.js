// =====================================================================
//  Modal de cancelamento de locação
// ---------------------------------------------------------------------
//  Pede o motivo (obrigatório, fica gravado no aluguel) e chama a função
//  cancelar_aluguel do banco pelo processo principal. Só aparece para
//  quem tem a permissão "Cancelar Locações".
// =====================================================================

document.addEventListener('DOMContentLoaded', () => {
  const form = document.getElementById('form-cancelar');
  const btnConfirmar = document.getElementById('btn-confirmar');

  function fechar() {
    window.apiAcesso.fecharModalCancelarLocacao();
  }
  document.getElementById('btn-voltar').addEventListener('click', fechar);
  document.getElementById('btn-fechar-topo').addEventListener('click', fechar);

  let locacao = null;
  try {
    locacao = JSON.parse(localStorage.getItem('locacaoParaCancelar'));
  } catch (e) {
    locacao = null;
  }
  localStorage.removeItem('locacaoParaCancelar');

  if (!locacao) {
    document.getElementById('texto-locacao').textContent = 'Aluguel não encontrado. Feche e tente de novo.';
    btnConfirmar.disabled = true;
    return;
  }

  document.getElementById('texto-locacao').textContent =
    `Aluguel #${locacao.id}: ${locacao.marca} ${locacao.modelo} (${formatarPlaca(locacao.placa)}) com ${locacao.cliente_nome}.`;

  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    btnConfirmar.disabled = true;
    try {
      const resposta = await window.apiAcesso.cancelarLocacao({
        locacao_id: locacao.id,
        motivo: document.getElementById('motivo').value,
      });
      if (resposta && resposta.sucesso) fechar();
    } catch (erro) {
      console.error('Erro ao cancelar locação:', erro);
    } finally {
      btnConfirmar.disabled = false;
    }
  });
});
