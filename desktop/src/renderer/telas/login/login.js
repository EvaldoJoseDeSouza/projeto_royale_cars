// =====================================================================
//  Tela de login
// ---------------------------------------------------------------------
//  Esta tela só junta o e-mail e a senha e manda pela "ponte"
//  (preload) para o processo principal. Quem confere tudo é o
//  processo principal junto com o Supabase (main/ipc/sessao.js).
//
//  Não existe mais "Criar conta" nem "Esqueci a senha": quem cria as
//  contas e redefine senhas é o chefe, pela Administração.
// =====================================================================

const formLogin = document.getElementById('form-login');

const btnTexto = document.getElementById('btn-texto');
const btnSpinner = document.getElementById('btn-spinner');
const btnCheck = document.getElementById('btn-check');

// Mostra no botão em que etapa o login está: 'normal', 'carregando' ou 'ok'
function mostrarEstadoDoBotao(estado) {
  if (btnTexto) btnTexto.style.display = estado === 'normal' ? 'inline-block' : 'none';
  if (btnSpinner) btnSpinner.style.display = estado === 'carregando' ? 'inline-block' : 'none';
  if (btnCheck) btnCheck.style.display = estado === 'ok' ? 'inline-block' : 'none';
}

if (formLogin) {
  formLogin.addEventListener('submit', async (event) => {
    event.preventDefault();

    const dados = new FormData(formLogin);
    const email = String(dados.get('email') || '').trim();
    const senha = String(dados.get('senha') || '');

    mostrarEstadoDoBotao('carregando');

    // Se der errado, o processo principal já mostra o aviso com o motivo
    const resposta = await window.apiAcesso.enviarLogin(email, senha);

    if (resposta.sucesso) {
      mostrarEstadoDoBotao('ok');
      setTimeout(() => window.apiAcesso.mudarDeTela(), 1500);
    } else {
      mostrarEstadoDoBotao('normal');
    }
  });
}

// Botão do "olhinho": mostra ou esconde a senha digitada
function configurarToggleSenha(idInput, idBotao, idIcone) {
  const inputSenha = document.getElementById(idInput);
  const btnOlho = document.getElementById(idBotao);
  const iconeOlho = document.getElementById(idIcone);

  if (inputSenha && btnOlho && iconeOlho) {
    btnOlho.addEventListener('click', () => {
      const tipoAtual = inputSenha.getAttribute('type');
      const novoTipo = tipoAtual === 'password' ? 'text' : 'password';
      inputSenha.setAttribute('type', novoTipo);

      iconeOlho.className = novoTipo === 'password' ? 'ri-eye-line' : 'ri-eye-off-line';
    });
  }
}

configurarToggleSenha('senha', 'btn-olho-login', 'ic-olho-login');
