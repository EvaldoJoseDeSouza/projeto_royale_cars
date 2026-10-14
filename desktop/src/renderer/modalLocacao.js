document.addEventListener('DOMContentLoaded', async () => {
    console.log("🚀 [DEBUG] JS do Modal de Locação foi lido pelo HTML! Iniciando carga de dados...");

    const formLocacao = document.getElementById('form-nova-locacao');
    const selectCliente = document.getElementById('select-cliente');
    const selectVeiculo = document.getElementById('select-veiculo');
    const inputDataInicio = document.getElementById('data-inicio');
    const inputDataFim = document.getElementById('data-fim');
    const btnCancelar = document.getElementById('btn-cancelar');

    const txtDiaria = document.getElementById('resumo-diaria');
    const txtDias = document.getElementById('resumo-dias');
    const txtTotal = document.getElementById('resumo-total');

    let listaVeiculosDisponiveis = [];
    let valorDiariaSelecionada = 0;

    async function carregarFormulario() {
        try {
            console.log("⏳ Buscando clientes e frota do banco via Preload...");

            const clientes = await window.apiAcesso.pedirClientes();
            console.log("👥 Clientes retornados do banco:", clientes);

            selectCliente.innerHTML = '<option value="">Selecione um Cliente...</option>';
            clientes.forEach(cli => {
                selectCliente.innerHTML += `<option value="${cli.id}">${cli.nome} (CPF: ${cli.cpf})</option>`;
            });

            const frotaCompleta = await window.apiAcesso.pedirFrota();
            console.log("🚗 Frota completa retornada do banco:", frotaCompleta);

            listaVeiculosDisponiveis = frotaCompleta.filter(carro => carro.status === 'Disponível');

            selectVeiculo.innerHTML = '<option value="">Selecione um Veículo...</option>';
            if (listaVeiculosDisponiveis.length === 0) {
                selectVeiculo.innerHTML = '<option value="">Nenhum veículo disponível no momento</option>';
            } else {
                listaVeiculosDisponiveis.forEach(carro => {
                    selectVeiculo.innerHTML += `<option value="${carro.id}">${carro.modelo} - ${carro.marca} (${carro.placa})</option>`;
                });
            }
        } catch (erro) {
            console.error("❌ Erro catastrófico ao popular seletores do modal de locação:", erro);
        }
    }

    function calcularLocacao() {
        const veiculoId = selectVeiculo.value;
        const dataInicioStr = inputDataInicio.value;
        const dataFimStr = inputDataFim.value;

        if (veiculoId) {
            const carroEncontrado = listaVeiculosDisponiveis.find(c => c.id == veiculoId);
            valorDiariaSelecionada = carroEncontrado ? carroEncontrado.diaria : 0;
        } else {
            valorDiariaSelecionada = 0;
        }

        txtDiaria.textContent = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(valorDiariaSelecionada);

        if (dataInicioStr && dataFimStr) {
            const d1 = new Date(dataInicioStr);
            const d2 = new Date(dataFimStr);

            const diferencaTempo = d2.getTime() - d1.getTime();
            let totalDias = Math.ceil(diferencaTempo / (1000 * 60 * 60 * 24));

            if (totalDias <= 0) totalDias = 1;

            const valorTotalGeral = totalDias * valorDiariaSelecionada;

            txtDias.textContent = `${totalDias} ${totalDias === 1 ? 'dia' : 'dias'}`;
            txtTotal.textContent = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(valorTotalGeral);
        } else {
            txtDias.textContent = "0 dias";
            txtTotal.textContent = "R$ 0,00";
        }
    }

    selectVeiculo.addEventListener('change', calcularLocacao);
    inputDataInicio.addEventListener('change', calcularLocacao);
    inputDataFim.addEventListener('change', calcularLocacao);

    formLocacao.addEventListener('submit', async (e) => {
        e.preventDefault();

        const d1 = new Date(inputDataInicio.value);
        const d2 = new Date(inputDataFim.value);
        let totalDias = Math.ceil((d2.getTime() - d1.getTime()) / (1000 * 60 * 60 * 24));
        if (totalDias <= 0) totalDias = 1;

        const valorTotalFinal = totalDias * valorDiariaSelecionada;

        const novaLocacao = {
            id_cliente: parseInt(selectCliente.value),
            id_veiculo: parseInt(selectVeiculo.value),
            data_inicio: inputDataInicio.value,
            data_fim: inputDataFim.value,
            valor_total: valorTotalFinal,
            status: 'Ativo'
        };

        try {
            const resultado = await window.apiAcesso.salvarLocacaoBanco(novaLocacao);

            if (resultado.sucesso) {
                window.apiAcesso.fecharModalLocacao();
            }
        } catch (erro) {
            console.error("Erro ao enviar dados da nova locação:", erro);
        }
    });

    if (btnCancelar) {
        btnCancelar.addEventListener('click', () => {
            window.apiAcesso.fecharModalLocacao();
        });
    }

    const btnFecharTopo = document.getElementById('btn-fechar-topo');
    if (btnFecharTopo) {
        btnFecharTopo.addEventListener('click', () => {
            window.apiAcesso.fecharModalLocacao();
        });
    }

    carregarFormulario();
});