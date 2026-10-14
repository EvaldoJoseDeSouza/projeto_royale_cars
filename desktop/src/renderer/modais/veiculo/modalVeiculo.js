// =====================================================================
//  Modal de veículo: cadastrar ou editar
// ---------------------------------------------------------------------
//  Não tem campo de status: quem muda o status são os aluguéis e as
//  manutenções (ver main/ipc/frota.js). Na edição, o status atual só
//  aparece escrito, para informação.
//
//  formatarPlaca, mascaraDinheiro, formatarDinheiro, soDigitos e
//  aplicarMascara vêm de ../../compartilhado/formatos.js.
// =====================================================================

document.addEventListener('DOMContentLoaded', () => {
  const form = document.getElementById('form-cadastro-veiculo');
  const btnSalvar = document.getElementById('btn-salvar');

  const campos = {
    marca: document.getElementById('marca'),
    modelo: document.getElementById('modelo'),
    ano: document.getElementById('ano'),
    placa: document.getElementById('placa'),
    chassi: document.getElementById('chassi'),
    valor_diaria: document.getElementById('valor-diaria'),
    quilometragem: document.getElementById('quilometragem'),
  };

  // O ano máximo é o do ano que vem (carro "ano/modelo" seguinte)
  campos.ano.max = new Date().getFullYear() + 1;

  // Máscaras: só ajudam a digitar. Quem limpa e confere é o processo principal.
  aplicarMascara(campos.placa, formatarPlaca);
  aplicarMascara(campos.chassi, (v) => v.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 17));
  aplicarMascara(campos.valor_diaria, mascaraDinheiro);
  aplicarMascara(campos.quilometragem, (v) => {
    const numeros = soDigitos(v).slice(0, 7);
    return numeros ? Number(numeros).toLocaleString('pt-BR') : '';
  });

  // Se o dashboard deixou um veículo no localStorage, estamos EDITANDO
  let veiculoEditando = null;
  try {
    const salvo = localStorage.getItem('veiculoParaEditar');
    if (salvo) veiculoEditando = JSON.parse(salvo);
  } catch (e) {
    veiculoEditando = null;
  }
  localStorage.removeItem('veiculoParaEditar'); // usou, apagou

  if (veiculoEditando) {
    document.getElementById('titulo-modal-veiculo').textContent = 'Editar Veículo';
    btnSalvar.textContent = 'Salvar Alterações';

    // textContent + <strong> criado à parte: o status vem do banco
    const textoStatus = document.getElementById('texto-status');
    textoStatus.textContent = 'Status atual: ';
    const destaque = document.createElement('strong');
    destaque.textContent = veiculoEditando.status;
    textoStatus.append(destaque, ' (muda sozinho com aluguéis e manutenções).');

    campos.marca.value = veiculoEditando.marca || '';
    campos.modelo.value = veiculoEditando.modelo || '';
    campos.ano.value = veiculoEditando.ano || '';
    campos.placa.value = formatarPlaca(veiculoEditando.placa);
    campos.chassi.value = veiculoEditando.chassi || '';
    campos.valor_diaria.value = formatarDinheiro(veiculoEditando.valor_diaria);
    campos.quilometragem.value = Number(veiculoEditando.quilometragem || 0).toLocaleString('pt-BR');

    // Carro alugado: a quilometragem é atualizada na devolução (regra do banco)
    if (veiculoEditando.status === 'Alugado') {
      campos.quilometragem.readOnly = true;
      campos.quilometragem.title = 'Atualizada na devolução';
    }
  }

  function fechar() {
    window.apiAcesso.fecharModalCadastro();
  }
  document.getElementById('btn-cancelar').addEventListener('click', fechar);
  document.getElementById('btn-fechar-topo').addEventListener('click', fechar);

  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const dados = { id: veiculoEditando ? veiculoEditando.id : null };
    Object.keys(campos).forEach((chave) => {
      dados[chave] = campos[chave].value;
    });

    btnSalvar.disabled = true;
    try {
      const resposta = await window.apiAcesso.salvarVeiculo(dados);
      if (resposta && resposta.sucesso) fechar();
    } catch (erro) {
      console.error('Erro ao salvar veículo:', erro);
    } finally {
      btnSalvar.disabled = false;
    }
  });
});
