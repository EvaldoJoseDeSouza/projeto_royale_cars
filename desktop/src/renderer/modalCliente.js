const form = document.getElementById('form-cadastro-cliente');
const btnCancelar = document.getElementById('btn-cancelar');
const btnFecharTopo = document.getElementById('btn-fechar-topo');

const inputCpf = document.getElementById('cpf');
const inputCnh = document.getElementById('cnh');
const inputTelefone = document.getElementById('telefone');

let idClienteEdicao = null;

const clienteSessao = localStorage.getItem('clienteParaEditar');
if (clienteSessao) {
    try {
        const cliente = JSON.parse(clienteSessao);
        idClienteEdicao = cliente.id; 

        if (document.getElementById('nome')) document.getElementById('nome').value = cliente.nome || '';
        if (inputCpf) inputCpf.value = cliente.cpf || '';
        if (inputCnh) inputCnh.value = cliente.cnh || '';
        if (inputTelefone) inputTelefone.value = cliente.telefone || '';
        if (document.getElementById('email')) document.getElementById('email').value = cliente.email || '';
        if (document.getElementById('endereco')) document.getElementById('endereco').value = cliente.endereco || '';

        const tituloModal = document.querySelector('.modal-header h3') || document.querySelector('h2');
        if (tituloModal) tituloModal.textContent = 'Editar Cliente';

        const btnSalvarTexto = form ? form.querySelector('.btn-save') : null;
        if (btnSalvarTexto) btnSalvarTexto.textContent = 'Salvar Alterações';

    } catch (err) {
        console.error('Erro ao mapear cliente para edição:', err);
    }
   
}

// Mascara de Digitação
if (inputCpf) {
    inputCpf.addEventListener('input', (e) => {
        let value = e.target.value.replace(/\D/g, '');
        if (value.length > 11) value = value.slice(0, 11); 

        if (value.length > 9) {
            value = value.replace(/^(\d{3})(\d{3})(\d{3})(\d{1,2})$/, '$1.$2.$3-$4');
        } else if (value.length > 6) {
            value = value.replace(/^(\d{3})(\d{3})(\d{1,3})$/, '$1.$2.$3');
        } else if (value.length > 3) {
            value = value.replace(/^(\d{3})(\d{1,3})$/, '$1.$2');
        }
        e.target.value = value;
    });
}

if (inputCnh) {
    inputCnh.addEventListener('input', (e) => {
        let value = e.target.value.replace(/\D/g, ''); 
        if (value.length > 11) value = value.slice(0, 11); 
        e.target.value = value;
    });
}

if (inputTelefone) {
    inputTelefone.addEventListener('input', (e) => {
        let value = e.target.value.replace(/\D/g, ''); 
        if (value.length > 11) value = value.slice(0, 11); 

        if (value.length > 10) {
            value = value.replace(/^(\d{2})(\d{5})(\d{4})$/, '($1) $2-$3');
        } else if (value.length > 6) {
            value = value.replace(/^(\d{2})(\d{4})(\d{4})$/, '($1) $2-$3');
        } else if (value.length > 2) {
            value = value.replace(/^(\d{2})(\d{1,4})$/, '($1) $2');
        } else if (value.length > 0) {
            value = value.replace(/^(\d{1,2})$/, '($1');
        }
        e.target.value = value;
    });
}

function fecharJanela() {
    window.close();
}

btnCancelar.addEventListener('click', fecharJanela);
btnFecharTopo.addEventListener('click', fecharJanela);

form.addEventListener('submit', async (e) => {
  e.preventDefault();

  const nome = document.getElementById('nome').value;
  const cpf = document.getElementById('cpf').value;
  const cnh = document.getElementById('cnh').value;
  const telefone = document.getElementById('telefone').value;
  const email = document.getElementById('email').value || null;
  const endereco = document.getElementById('endereco').value || null;

  const dadosCliente = { nome, cpf, cnh, telefone, email, endereco };

  if (idClienteEdicao) {
    dadosCliente.id = idClienteEdicao;
  }

  try {
    const resultado = await window.apiAcesso.salvarCliente(dadosCliente);

    if (resultado.sucesso) {
        localStorage.removeItem('clienteParaEditar');
        fecharJanela();
    }
  } catch (error) {
    console.error("Erro ao enviar submit do cliente:", error);
  }
});

btnCancelar.addEventListener('click', () => window.apiAcesso.fecharModalCliente());
btnFecharTopo.addEventListener('click', () => window.apiAcesso.fecharModalCliente());