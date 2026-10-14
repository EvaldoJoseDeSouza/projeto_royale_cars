document.addEventListener('DOMContentLoaded', () => {
    const btnFecharTopo = document.getElementById('btn-fechar-topo');
    const btnCancelar = document.getElementById('btn-cancelar');
    const formCadastro = document.getElementById('form-cadastro-veiculo');
    const inputPlaca = document.getElementById('placa');
    const inputDiaria = document.getElementById('diaria');

    let idVeiculoEdicao = null;

    const veiculoSessao = localStorage.getItem('veiculoParaEditar');
    if (veiculoSessao) {
        try {
            const carro = JSON.parse(veiculoSessao);
            idVeiculoEdicao = carro.id;

            document.getElementById('modelo').value = carro.modelo || '';
            document.getElementById('marca').value = carro.marca || '';
            if (inputPlaca) inputPlaca.value = carro.placa || '';
            
            const tituloModal = document.querySelector('.modal-header h3') || document.querySelector('h2');
            if (tituloModal) tituloModal.textContent = 'Editar Veículo';
            
            const btnSalvarTexto = formCadastro ? formCadastro.querySelector('.btn-save') : null;
            if (btnSalvarTexto) btnSalvarTexto.textContent = 'Salvar Alterações';

            if (inputDiaria && carro.diaria) {
                const opcoes = { minimumFractionDigits: 2, style: 'currency', currency: 'BRL' };
                inputDiaria.value = new Intl.NumberFormat('pt-BR', opcoes).format(carro.diaria);
            }
            
            if (document.getElementById('status')) {
                document.getElementById('status').value = carro.status || 'Disponível';
            }
        } catch (err) {
            console.error('Erro ao mapear veículo para edição:', err);
        }

        localStorage.removeItem('veiculoParaEditar');
    }

    if (inputPlaca) {
        inputPlaca.addEventListener('input', (e) => {
            let value = e.target.value.replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
            if (value.length > 7) value = value.slice(0, 7);

            if (value.length === 7 && /^[A-Z]{3}[0-9]{4}$/.test(value)) {
                value = value.replace(/^([A-Z]{3})([0-9]{4})$/, '$1-$2');
            }
            e.target.value = value;
        });
    }

    if (inputDiaria) {
        inputDiaria.addEventListener('input', (e) => {
            let value = e.target.value.replace(/\D/g, '');
            if (value === '') {
                e.target.value = '';
                return;
            }
            const opcoes = { minimumFractionDigits: 2, style: 'currency', currency: 'BRL' };
            const valorFormatado = new Intl.NumberFormat('pt-BR', opcoes).format(parseFloat(value) / 100);
            e.target.value = valorFormatado;
        });
    }

    if (btnFecharTopo) {
        btnFecharTopo.addEventListener('click', () => {
            window.apiAcesso.fecharModalCadastro();
        });
    }

    if (btnCancelar) {
        btnCancelar.addEventListener('click', () => {
            window.apiAcesso.fecharModalCadastro();
        });
    }

    if (formCadastro) {
        formCadastro.addEventListener('submit', async (e) => {
            e.preventDefault();

            const btnSalvar = formCadastro.querySelector('.btn-save');
            if (btnSalvar) btnSalvar.disabled = true;

            const valorDiariaRaw = document.getElementById('diaria').value;
            const valorLimpo = valorDiariaRaw
                .replace(/[R$\s]/g, '')    
                .replace(/\./g, '')       
                .replace(',', '.');        

            const valorFinalDiaria = parseFloat(valorLimpo) || 0;

            const dadosVeiculo = {
                modelo: document.getElementById('modelo').value,
                marca: document.getElementById('marca').value,
                placa: document.getElementById('placa').value.toUpperCase(),
                diaria: valorFinalDiaria, 
                status: document.getElementById('status').value
            };

            if (idVeiculoEdicao) {
                dadosVeiculo.id = idVeiculoEdicao;
            }

            const resposta = await window.apiAcesso.salvarVeiculo(dadosVeiculo);

            if (resposta.sucesso) {
                sessionStorage.removeItem('veiculoParaEditar');
                window.apiAcesso.fecharModalCadastro();
            } else {
                if (btnSalvar) btnSalvar.disabled = false;
            }
        });
    }
});