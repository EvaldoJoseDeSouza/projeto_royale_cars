// =====================================================================
//  Modal "Liberar da oficina"
// ---------------------------------------------------------------------
//  Serviço feito, custo e data. Quem grava é a função concluir_manutencao
//  do banco (main/ipc/manutencoes.js): o carro volta a ficar Disponível e
//  o custo entra no Financeiro das 3 plataformas.
//
//  Os dados da manutenção chegam pelo localStorage
//  ("manutencaoParaLiberar"), deixados pelo dashboard ao clicar em Liberar.
// =====================================================================

document.addEventListener('DOMContentLoaded', () => {
  const form = document.getElementById('form-liberar');
  const btnSalvar = document.getElementById('btn-salvar');
  const campoCusto = document.getElementById('custo');
  const campoData = document.getElementById('data-liberacao');

  function fechar() {
    window.apiAcesso.fecharModalLiberarManutencao();
  }
  document.getElementById('btn-cancelar').addEventListener('click', fechar);
  document.getElementById('btn-fechar-topo').addEventListener('click', fechar);

  // ----------------------------------------- QUAL MANUTENÇÃO É ESTA?
  let manutencao = null;
  try {
    manutencao = JSON.parse(localStorage.getItem('manutencaoParaLiberar'));
  } catch (e) {
    manutencao = null;
  }
  localStorage.removeItem('manutencaoParaLiberar'); // usou, apagou

  if (!manutencao) {
    document.getElementById('ficha-manutencao').textContent = 'Manutenção não encontrada. Feche e tente de novo.';
    btnSalvar.disabled = true;
    return;
  }

  // Ficha da manutenção. Montada com textContent: os textos vêm do banco.
  const carro = manutencao.veiculos || {};
  const ficha = document.getElementById('ficha-manutencao');
  [
    `${carro.marca || ''} ${carro.modelo || ''} (${formatarPlaca(carro.placa)})`,
    `Defeito: ${manutencao.defeito}`,
    `Na oficina desde ${formatarData(manutencao.data_entrada)} (${diasEntre(manutencao.data_entrada, hojeTexto())} dia(s))`,
  ].forEach((texto) => {
    const linha = document.createElement('div');
    linha.textContent = texto;
    ficha.appendChild(linha);
  });

  // -------------------------------------------------------- CAMPOS
  // Liberação: entre a entrada na oficina e hoje (regra do banco)
  const hoje = hojeTexto();
  campoData.value = hoje;
  campoData.min = manutencao.data_entrada;
  campoData.max = hoje;

  aplicarMascara(campoCusto, mascaraDinheiro);

  // ------------------------------------------------------- SALVAR
  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const dados = {
      manutencao_id: manutencao.id,
      servico: document.getElementById('servico').value,
      custo: campoCusto.value,
      data_liberacao: campoData.value,
    };

    btnSalvar.disabled = true;
    try {
      const resposta = await window.apiAcesso.concluirManutencao(dados);
      if (resposta && resposta.sucesso) fechar();
    } catch (erro) {
      console.error('Erro ao liberar da oficina:', erro);
    } finally {
      btnSalvar.disabled = false;
    }
  });
});
