// =====================================================================
//  Modal de cliente: cadastrar ou editar
// ---------------------------------------------------------------------
//  As máscaras (CPF e telefone) só ajudam quem digita. Quem limpa os
//  dados e confere é o processo principal (main/ipc/clientes.js) e, por
//  último, o banco. Se algo estiver errado, o aviso já vem com o motivo.
//
//  formatarCpf, formatarTelefone, soDigitos e aplicarMascara vêm de
//  ../../compartilhado/formatos.js (carregado antes deste arquivo).
// =====================================================================

document.addEventListener('DOMContentLoaded', () => {
  const form = document.getElementById('form-cadastro-cliente');
  const btnSalvar = document.getElementById('btn-salvar');

  const campos = {
    nome: document.getElementById('nome'),
    cpf: document.getElementById('cpf'),
    telefone: document.getElementById('telefone'),
    cnh: document.getElementById('cnh'),
    cnh_validade: document.getElementById('cnh-validade'),
    email: document.getElementById('email'),
    endereco: document.getElementById('endereco'),
  };

  // Máscaras: CPF e telefone formatados, CNH só números
  aplicarMascara(campos.cpf, formatarCpf);
  aplicarMascara(campos.telefone, formatarTelefone);
  aplicarMascara(campos.cnh, (valor) => soDigitos(valor).slice(0, 11));

  // Se o dashboard deixou um cliente no localStorage, estamos EDITANDO
  let clienteEditando = null;
  try {
    const salvo = localStorage.getItem('clienteParaEditar');
    if (salvo) clienteEditando = JSON.parse(salvo);
  } catch (e) {
    clienteEditando = null;
  }
  localStorage.removeItem('clienteParaEditar'); // usou, apagou

  if (clienteEditando) {
    document.getElementById('titulo-modal-cliente').textContent = 'Editar Cliente';
    btnSalvar.textContent = 'Salvar Alterações';

    // O banco guarda só números: aqui eles ganham a máscara de novo
    campos.nome.value = clienteEditando.nome || '';
    campos.cpf.value = formatarCpf(clienteEditando.cpf);
    campos.telefone.value = formatarTelefone(clienteEditando.telefone);
    campos.cnh.value = clienteEditando.cnh || '';
    campos.cnh_validade.value = clienteEditando.cnh_validade || '';
    campos.email.value = clienteEditando.email || '';
    campos.endereco.value = clienteEditando.endereco || '';
  }

  function fechar() {
    window.apiAcesso.fecharModalCliente();
  }
  document.getElementById('btn-cancelar').addEventListener('click', fechar);
  document.getElementById('btn-fechar-topo').addEventListener('click', fechar);

  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    // Junta todos os campos num objeto só. Na edição vai TUDO (antes o
    // e-mail e o endereço ficavam de fora e não eram salvos).
    const dados = { id: clienteEditando ? clienteEditando.id : null };
    Object.keys(campos).forEach((chave) => {
      dados[chave] = campos[chave].value;
    });

    btnSalvar.disabled = true;
    try {
      const resposta = await window.apiAcesso.salvarCliente(dados);
      if (resposta && resposta.sucesso) fechar();
    } catch (erro) {
      console.error('Erro ao salvar cliente:', erro);
    } finally {
      btnSalvar.disabled = false;
    }
  });
});
