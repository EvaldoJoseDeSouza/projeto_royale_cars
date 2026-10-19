// =====================================================================
//  Modal "Enviar para a oficina"
// ---------------------------------------------------------------------
//  Monta os dados e entrega para main/ipc/manutencoes.js, que chama a
//  função abrir_manutencao do banco (a mesma da web e do celular).
//
//  Se a pessoa clicou em "Enviar para oficina" no cartão de um carro da
//  Frota, o carro já vem escolhido (pelo localStorage
//  "veiculoParaManutencao", o mesmo jeito dos outros modais).
// =====================================================================

// Os 4 itens da vistoria, na mesma ordem e com os mesmos nomes da web
const ITENS_VISTORIA = [
  { chave: 'motor', nome: 'Motor' },
  { chave: 'freios', nome: 'Freios' },
  { chave: 'pneus', nome: 'Pneus' },
  { chave: 'oleo', nome: 'Óleo' },
];

document.addEventListener('DOMContentLoaded', async () => {
  const form = document.getElementById('form-manutencao');
  const btnSalvar = document.getElementById('btn-salvar');
  const selectVeiculo = document.getElementById('select-veiculo');
  const campoEntrada = document.getElementById('data-entrada');
  const campoPrevisao = document.getElementById('previsao');
  const checkVistoria = document.getElementById('fazer-vistoria');

  function fechar() {
    window.apiAcesso.fecharModalManutencao();
  }
  document.getElementById('btn-cancelar').addEventListener('click', fechar);
  document.getElementById('btn-fechar-topo').addEventListener('click', fechar);

  // -------------------------------------------------------- DATAS
  // Entrada: de hoje até 30 dias atrás (regra do banco)
  const hoje = hojeTexto();
  campoEntrada.value = hoje;
  campoEntrada.max = hoje;
  campoEntrada.min = somarDias(hoje, -30);

  // A previsão não pode ser antes da entrada
  function ajustarPrevisao() {
    campoPrevisao.min = campoEntrada.value;
    if (campoPrevisao.value && campoPrevisao.value < campoEntrada.value) campoPrevisao.value = '';
  }
  campoEntrada.addEventListener('change', ajustarPrevisao);
  ajustarPrevisao();

  // ------------------------------------------------------ VISTORIA
  // Cada item tem 3 respostas: OK, com problema ou não conferido
  const caixaVistoria = document.getElementById('vistoria');
  ITENS_VISTORIA.forEach(({ chave, nome }) => {
    const bloco = document.createElement('div');
    bloco.innerHTML = `
      <label for="item-${chave}">${nome}</label>
      <select id="item-${chave}">
        <option value="ok">OK</option>
        <option value="problema">Com problema</option>
        <option value="">Não conferido</option>
      </select>
    `;
    caixaVistoria.appendChild(bloco);
  });

  checkVistoria.addEventListener('change', () => {
    document.getElementById('bloco-vistoria').style.display = checkVistoria.checked ? 'block' : 'none';
  });

  // ------------------------------------------------------- VEÍCULOS
  // Só carro Disponível vai para a oficina por aqui (o banco confere de novo)
  let veiculoEscolhido = null;
  try {
    veiculoEscolhido = JSON.parse(localStorage.getItem('veiculoParaManutencao'));
  } catch (e) {
    veiculoEscolhido = null;
  }
  localStorage.removeItem('veiculoParaManutencao'); // usou, apagou

  try {
    const frota = await window.apiAcesso.pedirFrota();
    const disponiveis = frota.filter((carro) => carro.status === 'Disponível');

    selectVeiculo.innerHTML = '';
    if (disponiveis.length === 0) {
      selectVeiculo.innerHTML = '<option value="">Nenhum carro disponível agora</option>';
      btnSalvar.disabled = true;
    } else {
      selectVeiculo.innerHTML = '<option value="">Escolha o veículo</option>';
      disponiveis.forEach((carro) => {
        const opcao = document.createElement('option');
        opcao.value = carro.id;
        // textContent: o nome vem do banco, entra como texto (nunca como HTML)
        opcao.textContent = `${carro.marca} ${carro.modelo} (${formatarPlaca(carro.placa)}) · ${formatarKm(carro.quilometragem)}`;
        selectVeiculo.appendChild(opcao);
      });
      if (veiculoEscolhido) selectVeiculo.value = String(veiculoEscolhido.id);
    }
  } catch (erro) {
    console.error('Erro ao carregar a frota:', erro);
    selectVeiculo.innerHTML = '<option value="">Não foi possível carregar a frota</option>';
    btnSalvar.disabled = true;
  }

  // ------------------------------------------------------- SALVAR
  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const checklist = {};
    ITENS_VISTORIA.forEach(({ chave }) => {
      checklist[chave] = document.getElementById(`item-${chave}`).value;
    });

    const dados = {
      veiculo_id: selectVeiculo.value,
      defeito: document.getElementById('defeito').value,
      oficina: document.getElementById('oficina').value,
      data_entrada: campoEntrada.value,
      previsao: campoPrevisao.value,
      fazer_vistoria: checkVistoria.checked,
      checklist,
    };

    btnSalvar.disabled = true;
    try {
      const resposta = await window.apiAcesso.abrirManutencao(dados);
      if (resposta && resposta.sucesso) fechar();
    } catch (erro) {
      console.error('Erro ao enviar para a oficina:', erro);
    } finally {
      btnSalvar.disabled = false;
    }
  });
});
