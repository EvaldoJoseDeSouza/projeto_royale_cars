// =====================================================================
//  Modal de colaborador: cadastrar ou editar uma pessoa da equipe
// ---------------------------------------------------------------------
//  - CADASTRAR: nome, e-mail, cargo e permissões. Ao salvar, o processo
//    principal pede à Edge Function para criar o login e mostra a senha
//    temporária numa janela própria.
//  - EDITAR: os mesmos campos. Senha e desativar ficam no menu do cartão.
//
//  "Usar modelo" é só um atalho: marca as caixinhas do modelo escolhido.
//  Depois dá para marcar ou desmarcar uma por uma.
//
//  A lista das 13 permissões e o desenho das caixinhas vêm de
//  ../../compartilhado/permissoes.js (carregado antes deste arquivo).
// =====================================================================

document.addEventListener('DOMContentLoaded', async () => {
  const form = document.getElementById('form-colaborador');
  const inputNome = document.getElementById('colab-nome');
  const inputEmail = document.getElementById('colab-email');
  const selectCargo = document.getElementById('colab-cargo');
  const selectModelo = document.getElementById('colab-modelo');
  const listaPermissoes = document.getElementById('lista-permissoes');
  const contador = document.getElementById('contador-permissoes');
  const btnSalvar = document.getElementById('btn-salvar');

  // As caixinhas marcadas. Um Set é uma lista que não repete itens.
  let selecionadas = new Set();
  let modelos = [];

  // Se o dashboard deixou uma pessoa no localStorage, estamos EDITANDO
  let pessoaEditando = null;
  try {
    const salvo = localStorage.getItem('colaboradorParaEditar');
    if (salvo) pessoaEditando = JSON.parse(salvo);
  } catch (e) {
    pessoaEditando = null;
  }
  localStorage.removeItem('colaboradorParaEditar');

  function fechar() {
    window.apiAcesso.fecharModalColaborador();
  }
  document.getElementById('btn-cancelar').addEventListener('click', fechar);
  document.getElementById('btn-fechar-topo').addEventListener('click', fechar);

  function atualizarContador() {
    const total = selecionadas.size;
    contador.textContent = `${total} selecionada${total !== 1 ? 's' : ''}`;
  }

  // Redesenha as caixinhas. Se a pessoa mexer numa caixa, o modelo
  // escolhido deixa de valer (agora é uma combinação personalizada).
  function desenharPermissoes() {
    desenharListaPermissoes(listaPermissoes, selecionadas, () => {
      selectModelo.value = '';
      atualizarContador();
    });
    atualizarContador();
  }

  // ------------------------------------------------------- MODELOS
  async function carregarModelos() {
    modelos = await window.apiAcesso.pedirGruposPermissao();
    const escolhido = selectModelo.value;

    selectModelo.innerHTML = '<option value="">Escolha para marcar as permissões de uma vez...</option>';
    modelos.forEach((modelo) => {
      const opcao = document.createElement('option');
      opcao.value = modelo.id;
      opcao.textContent = `${modelo.nome} (${modelo.permissoes.length} permissões)`;
      selectModelo.appendChild(opcao);
    });
    selectModelo.value = escolhido;
  }

  selectModelo.addEventListener('change', () => {
    const modelo = modelos.find((m) => String(m.id) === selectModelo.value);
    if (!modelo) return;
    selecionadas = new Set(modelo.permissoes); // troca tudo pelas do modelo
    desenharPermissoes();
  });

  // Se o chefe mexer nos modelos com esta janela aberta, a lista atualiza
  window.apiAcesso.aoAtualizarGrupos(carregarModelos);

  await carregarModelos();

  // ------------------------------------------------- MODO EDIÇÃO
  if (pessoaEditando) {
    document.getElementById('titulo-modal-colaborador').textContent = 'Editar Colaborador';
    document.getElementById('texto-explicacao').textContent =
      'Para gerar outra senha ou desativar o acesso, use o menu do cartão na lista.';
    btnSalvar.textContent = 'Salvar alterações';

    inputNome.value = pessoaEditando.nome || '';
    inputEmail.value = pessoaEditando.email || '';
    selectCargo.value = pessoaEditando.cargo === 'gerente' ? 'gerente' : 'funcionario';
    selecionadas = new Set(pessoaEditando.permissoes || []);
  }

  desenharPermissoes();

  // ------------------------------------------------------- SALVAR
  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    const dados = {
      id: pessoaEditando ? pessoaEditando.id : null,
      nome: inputNome.value,
      email: inputEmail.value,
      cargo: selectCargo.value,
      permissoes: Array.from(selecionadas),
    };

    // Trava o botão: criar o login leva alguns segundos e um segundo
    // clique criaria a mesma pessoa duas vezes.
    btnSalvar.disabled = true;
    const textoOriginal = btnSalvar.textContent;
    btnSalvar.textContent = 'Salvando...';

    try {
      // Se der errado, o processo principal já mostra o aviso com o motivo
      const resposta = await window.apiAcesso.salvarColaborador(dados);
      if (resposta && resposta.sucesso) fechar();
    } catch (erro) {
      console.error('Erro ao salvar colaborador:', erro);
    } finally {
      btnSalvar.disabled = false;
      btnSalvar.textContent = textoOriginal;
    }
  });
});
