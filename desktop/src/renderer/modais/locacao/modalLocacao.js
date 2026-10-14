// =====================================================================
//  Modal de nova locação (retirada do carro)
// ---------------------------------------------------------------------
//  A conta mostrada aqui é só uma PRÉVIA para o atendente conversar com
//  o cliente. Quem calcula de verdade é a função registrar_aluguel do
//  banco (a mesma da web e do celular), chamada pelo processo principal.
//
//  As datas seguem as regras do banco: retirada entre 30 dias atrás e
//  hoje; devolução prevista a partir de hoje (e não antes da retirada).
//
//  formatarDinheiro, formatarPlaca, formatarCpf, hojeTexto, somarDias,
//  diasEntre, diasAte, soDigitos e aplicarMascara vêm de
//  ../../compartilhado/formatos.js.
// =====================================================================

document.addEventListener('DOMContentLoaded', async () => {
  const form = document.getElementById('form-nova-locacao');
  const selectCliente = document.getElementById('select-cliente');
  const selectVeiculo = document.getElementById('select-veiculo');
  const inputRetirada = document.getElementById('data-retirada');
  const inputPrevista = document.getElementById('data-prevista');
  const inputKm = document.getElementById('km-saida');
  const inputObs = document.getElementById('observacoes');
  const btnSalvar = document.getElementById('btn-salvar');

  let veiculosDisponiveis = [];

  // ----------------------------------------------- DATAS E LIMITES
  const hoje = hojeTexto();
  inputRetirada.value = hoje;
  inputRetirada.min = somarDias(hoje, -30);
  inputRetirada.max = hoje;
  inputPrevista.min = hoje;

  // Km: só números, com ponto de milhar enquanto digita
  aplicarMascara(inputKm, (v) => {
    const n = soDigitos(v).slice(0, 7);
    return n ? Number(n).toLocaleString('pt-BR') : '';
  });

  // ------------------------------------------------ CARREGAR LISTAS
  async function carregarListas() {
    const [clientes, frota] = await Promise.all([
      window.apiAcesso.pedirClientes(),
      window.apiAcesso.pedirFrota(),
    ]);

    // Clientes: quem está com a CNH vencida aparece, mas bloqueado
    selectCliente.innerHTML = '<option value="">Selecione o cliente...</option>';
    clientes.forEach((cliente) => {
      const opcao = document.createElement('option');
      opcao.value = cliente.id;
      const vencida = diasAte(cliente.cnh_validade) < 0;
      opcao.textContent = `${cliente.nome} (CPF ${formatarCpf(cliente.cpf)})${vencida ? ' - CNH vencida' : ''}`;
      opcao.disabled = vencida;
      opcao.dataset.cnhValidade = cliente.cnh_validade;
      selectCliente.appendChild(opcao);
    });

    // Veículos: só os disponíveis
    veiculosDisponiveis = frota.filter((carro) => carro.status === 'Disponível');
    selectVeiculo.innerHTML = veiculosDisponiveis.length
      ? '<option value="">Selecione o veículo...</option>'
      : '<option value="">Nenhum veículo disponível no momento</option>';
    veiculosDisponiveis.forEach((carro) => {
      const opcao = document.createElement('option');
      opcao.value = carro.id;
      opcao.textContent = `${carro.marca} ${carro.modelo} (${formatarPlaca(carro.placa)}) - ${formatarDinheiro(carro.valor_diaria)}/dia`;
      selectVeiculo.appendChild(opcao);
    });
  }

  // --------------------------------------------------------- PRÉVIA
  function veiculoEscolhido() {
    return veiculosDisponiveis.find((carro) => String(carro.id) === selectVeiculo.value);
  }

  function atualizarResumo() {
    const carro = veiculoEscolhido();
    const diaria = carro ? Number(carro.valor_diaria) : 0;
    document.getElementById('resumo-diaria').textContent = formatarDinheiro(diaria);

    const temDatas = inputRetirada.value && inputPrevista.value;
    // Igual ao banco: no mínimo 1 diária
    const dias = temDatas ? Math.max(1, diasEntre(inputRetirada.value, inputPrevista.value)) : 0;
    document.getElementById('resumo-dias').textContent = temDatas ? `${dias}` : '-';
    document.getElementById('resumo-total').textContent = formatarDinheiro(dias * diaria);
  }

  // Trocou o carro: a km de saída começa com a km atual dele
  selectVeiculo.addEventListener('change', () => {
    const carro = veiculoEscolhido();
    inputKm.value = carro ? Number(carro.quilometragem || 0).toLocaleString('pt-BR') : '';
    document.getElementById('dica-km').textContent = carro
      ? `Atual do veículo: ${formatarKm(carro.quilometragem)}. Não pode ser menor.`
      : 'O número do painel na hora da retirada.';
    atualizarResumo();
  });

  // A devolução prevista não pode ser antes da retirada (nem antes de hoje)
  inputRetirada.addEventListener('change', () => {
    inputPrevista.min = inputRetirada.value > hoje ? inputRetirada.value : hoje;
    atualizarResumo();
  });
  inputPrevista.addEventListener('change', atualizarResumo);

  // ------------------------------------------------------- FECHAR
  function fechar() {
    window.apiAcesso.fecharModalLocacao();
  }
  document.getElementById('btn-cancelar').addEventListener('click', fechar);
  document.getElementById('btn-fechar-topo').addEventListener('click', fechar);

  // ------------------------------------------------------- SALVAR
  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    btnSalvar.disabled = true;
    try {
      const resposta = await window.apiAcesso.registrarAluguel({
        cliente_id: selectCliente.value,
        veiculo_id: selectVeiculo.value,
        data_retirada: inputRetirada.value,
        data_prevista: inputPrevista.value,
        km_saida: inputKm.value,
        observacoes: inputObs.value,
      });
      if (resposta && resposta.sucesso) fechar();
    } catch (erro) {
      console.error('Erro ao registrar aluguel:', erro);
    } finally {
      btnSalvar.disabled = false;
    }
  });

  await carregarListas();
  atualizarResumo();
});
