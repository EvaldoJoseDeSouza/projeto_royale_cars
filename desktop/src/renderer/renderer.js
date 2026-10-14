const formLogin = document.getElementById('form-login');

if (formLogin) {
  formLogin.addEventListener('submit', async (event) => {
    event.preventDefault();

    const formData = new FormData(formLogin);
    const email = formData.get('email');
    const senha = formData.get('senha');

    const btnTexto = document.getElementById('btn-texto');
    const btnSpinner = document.getElementById('btn-spinner');
    const btnCheck = document.getElementById('btn-check');

    console.log('Disparando dados pela ponte...');

    if (btnTexto && btnSpinner) {
      btnTexto.style.display = 'none';
      btnSpinner.style.display = 'inline-block';
    }

    const resposta = await window.apiAcesso.enviarLogin(email, senha);

    console.log('Resposta recebida da nuvem:', resposta);

    if (resposta.sucesso) {
      if (btnSpinner && btnCheck) {
        btnSpinner.style.display = 'none';
        btnCheck.style.display = 'inline-block';
      }

      setTimeout(() => {
        window.apiAcesso.mudarDeTela();
      }, 3000);

    } else {
      if (btnTexto && btnSpinner) {
        btnTexto.style.display = 'inline-block';
        btnSpinner.style.display = 'none';
      }
    }
  });
}

const linkIrCadastro = document.getElementById('link-ir-cadastro');
const linkIrLogin = document.getElementById('link-ir-login');

const wrapperLogin = document.getElementById('wrapper-login');
const wrapperCadastro = document.getElementById('wrapper-cadastro');

if (linkIrCadastro && linkIrLogin && wrapperLogin && wrapperCadastro) {

  linkIrCadastro.addEventListener('click', (e) => {
    e.preventDefault();
    wrapperLogin.style.display = 'none';
    if (wrapperEsqueciSenha) wrapperEsqueciSenha.style.display = 'none';
    wrapperCadastro.style.display = 'block';
  });

  linkIrLogin.addEventListener('click', (e) => {
    e.preventDefault();
    wrapperCadastro.style.display = 'none';
    wrapperLogin.style.display = 'block';
  });
}

const formCriarConta = document.getElementById('form-criar-conta');

if (formCriarConta) {
  formCriarConta.addEventListener('submit', async (e) => {
    e.preventDefault();

    const empresa = document.getElementById('reg-empresa').value.trim();
    const email = document.getElementById('reg-email').value.trim();
    const senha = document.getElementById('reg-senha').value;

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      alert('Por favor, insira um e-mail válido (exemplo@empresa.com).');
      return;
    }

    if (senha.length < 6) {
      alert('Sua senha deve conter pelo menos 6 caracteres por motivos de segurança.');
      return;
    }

    if (!empresa || !email || !senha) {
      alert('Por favor, preencha todos os campos obrigatórios.');
      return;
    }

    const btnRegistrar = document.getElementById('btn-registrar');
    if (btnRegistrar) {
      btnRegistrar.disabled = true;
      btnRegistrar.textContent = 'Criando conta...';
    }

    try {
      const resposta = await window.apiAcesso.criarNovaConta({ empresa, email, senha });

      if (resposta.sucesso) {
        formCriarConta.reset();
        if (wrapperCadastro && wrapperLogin) {
          wrapperCadastro.style.display = 'none';
          wrapperLogin.style.display = 'block';
        }
      }
    } catch (error) {
      console.error('Erro no fluxo de registro:', error);
    } finally {
      if (btnRegistrar) {
        btnRegistrar.disabled = false;
        btnRegistrar.textContent = 'Criar Minha Conta';
      }
    }
  });
}

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
configurarToggleSenha('reg-senha', 'btn-olho-cadastro', 'ic-olho-cadastro');
configurarToggleSenha('esqueci-nova-senha', 'btn-olho-esqueci-nova', 'ic-olho-esqueci-nova');
configurarToggleSenha('esqueci-confirmar-senha', 'btn-olho-esqueci-confirmar', 'ic-olho-esqueci-confirmar');

const linkEsqueciSenha = document.getElementById('link-esqueci');
const linkVoltarLoginEsqueci = document.getElementById('link-voltar-login-esqueci');
const wrapperEsqueciSenha = document.getElementById('wrapper-esqueci-senha');
const passoEmail = document.getElementById('esqueci-passo-email');
const passoSenha = document.getElementById('esqueci-passo-senha');

let emailParaRedefinir = null;

function resetarFluxoEsqueciSenha() {
  emailParaRedefinir = null;
  passoEmail.style.display = 'block';
  passoSenha.style.display = 'none';
  document.getElementById('esqueci-email').value = '';
  document.getElementById('esqueci-nova-senha').value = '';
  document.getElementById('esqueci-confirmar-senha').value = '';

  const btnVerificarEmail = document.getElementById('btn-verificar-email');
  const btnTextoReset = document.getElementById('btn-verificar-texto');
  const btnSpinnerReset = document.getElementById('btn-verificar-spinner');
  const btnCheckReset = document.getElementById('btn-verificar-check');

  if (btnVerificarEmail) btnVerificarEmail.disabled = false;
  if (btnTextoReset) btnTextoReset.style.display = 'inline-block';
  if (btnSpinnerReset) btnSpinnerReset.style.display = 'none';
  if (btnCheckReset) btnCheckReset.style.display = 'none';
}

if (linkEsqueciSenha && wrapperLogin && wrapperEsqueciSenha) {
  linkEsqueciSenha.addEventListener('click', (e) => {
    e.preventDefault();
    resetarFluxoEsqueciSenha(); 
    wrapperLogin.style.display = 'none';
    wrapperEsqueciSenha.style.display = 'block';
  });
}

if (linkVoltarLoginEsqueci && wrapperLogin && wrapperEsqueciSenha) {
  linkVoltarLoginEsqueci.addEventListener('click', (e) => {
    e.preventDefault();
    wrapperEsqueciSenha.style.display = 'none';
    wrapperLogin.style.display = 'block';
  });
}

const btnVerificarEmail = document.getElementById('btn-verificar-email');
if (btnVerificarEmail) {
  btnVerificarEmail.addEventListener('click', async () => {
    const email = document.getElementById('esqueci-email').value.trim();

    if (!email) {
      alert('Por favor, insira um e-mail.');
      return;
    }

    const btnTextoVerificar = document.getElementById('btn-verificar-texto');
    const btnSpinnerVerificar = document.getElementById('btn-verificar-spinner');
    const btnCheckVerificar = document.getElementById('btn-verificar-check');

    btnVerificarEmail.disabled = true;
    if (btnTextoVerificar && btnSpinnerVerificar) {
      btnTextoVerificar.style.display = 'none';
      btnSpinnerVerificar.style.display = 'inline-block';
    }

    try {
      const resposta = await window.apiAcesso.verificarEmailExiste(email);

      if (resposta.sucesso && resposta.existe) {
        if (btnSpinnerVerificar && btnCheckVerificar) {
          btnSpinnerVerificar.style.display = 'none';
          btnCheckVerificar.style.display = 'inline-block';
        }

        setTimeout(() => {
          emailParaRedefinir = email;
          passoEmail.style.display = 'none';
          passoSenha.style.display = 'block';
        }, 1200);
      } else {
        btnVerificarEmail.disabled = false;
        if (btnTextoVerificar && btnSpinnerVerificar) {
          btnTextoVerificar.style.display = 'inline-block';
          btnSpinnerVerificar.style.display = 'none';
        }
      }
    } catch (erro) {
      console.error('Erro ao verificar e-mail:', erro);
      btnVerificarEmail.disabled = false;
      if (btnTextoVerificar && btnSpinnerVerificar) {
        btnTextoVerificar.style.display = 'inline-block';
        btnSpinnerVerificar.style.display = 'none';
      }
    }
  });
}

const btnRedefinirSenha = document.getElementById('btn-redefinir-senha');
if (btnRedefinirSenha) {
  btnRedefinirSenha.addEventListener('click', async () => {
    const novaSenha = document.getElementById('esqueci-nova-senha').value;
    const confirmarSenha = document.getElementById('esqueci-confirmar-senha').value;

    if (novaSenha.length < 6) {
      alert('Sua senha deve conter pelo menos 6 caracteres  por motivos de segurança.');
      return;
    }

    if (novaSenha !== confirmarSenha) {
      alert('As senha não coincidem. Verifique e tente novamente.');
      return;
    }

    btnRedefinirSenha.disabled = true;
    btnRedefinirSenha.textContent = 'Redefinindo...';

    try {
      const resposta = await window.apiAcesso.redefinirSenhaEsqueci({
        email: emailParaRedefinir,
        novaSenha
      });

      if (resposta.sucesso) {
        const emailRedefinido = emailParaRedefinir;
        wrapperEsqueciSenha.style.display = 'none';
        wrapperLogin.style.display = 'block';
        document.getElementById('email').value = emailRedefinido;
        resetarFluxoEsqueciSenha();
      }
    } catch (erro) {
      console.error('Erro ao redefinir senha:', erro);
    } finally {
      btnRedefinirSenha.disabled = false;
      btnRedefinirSenha.textContent = 'Redefinir Senha';
    }
  });
}