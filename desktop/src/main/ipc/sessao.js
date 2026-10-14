// =====================================================================
//  IPC da sessão: login e troca de senha
// ---------------------------------------------------------------------
//  O login segue o MESMO roteiro nas 3 plataformas (web, desktop e
//  celular), combinado no plano de unificação:
//
//    1. Pergunta ao banco se o e-mail está bloqueado (5 erros em 15 min)
//    2. Tenta entrar pelo Supabase Auth (e-mail + senha)
//    3. Registra a tentativa (certa ou errada) para o painel do chefe
//    4. Pede ao banco o perfil e as permissões (iniciar_sessao)
//       - se a pessoa estiver desativada, o banco recusa e saímos
//    5. Guarda o perfil na sessão
//
//  Quem confere a senha é o Supabase, não o app. O app nunca vê o hash.
// =====================================================================

const { ipcMain } = require("electron");
const supabase = require("../supabase");
const { sessao } = require("../sessao");

const PLATAFORMA = "desktop";

// Mesma regra de senha das 3 plataformas: 8+ caracteres, com letra e número
function senhaForte(senha) {
  return typeof senha === "string" && senha.length >= 8 && /[A-Za-z]/.test(senha) && /\d/.test(senha);
}

// Grava a tentativa no banco. Se falhar, só avisa no console:
// não pode impedir a pessoa de entrar por causa do registro.
async function registrarTentativa(email, sucesso, motivo) {
  const { error } = await supabase.rpc("registrar_tentativa_login", {
    p_email: email,
    p_sucesso: sucesso,
    p_motivo: motivo,
    p_plataforma: PLATAFORMA,
  });
  if (error) console.error("Erro ao registrar tentativa de login:", error.message);
}

// "deps" são as coisas que moram no index.js e este arquivo precisa usar:
//   mostrarAviso(janela, { tipo, titulo, mensagem })
//   obterJanelaPrincipal()       → a janela de login
//   obterJanelaTrocarSenha()     → o modal de trocar senha
//   obterJanelaDashboard()       → a janela principal do sistema
function registrarIpcSessao(deps) {
  const { mostrarAviso, obterJanelaPrincipal, obterJanelaTrocarSenha, obterJanelaDashboard } = deps;

  const avisarNoLogin = (titulo, mensagem) =>
    mostrarAviso(obterJanelaPrincipal(), { tipo: "erro", titulo, mensagem });

  // ------------------------------------------------------------- LOGIN
  ipcMain.handle("realizar-login", async (event, { login, senha }) => {
    try {
      const email = String(login || "").trim().toLowerCase();

      if (!email.includes("@")) {
        await avisarNoLogin("Erro no login", "Entre com o seu e-mail de acesso.");
        return { sucesso: false };
      }

      // 1. Bloqueado por muitas tentativas?
      const { data: bloqueado, error: erroBloqueio } = await supabase.rpc("login_bloqueado", { p_email: email });
      if (erroBloqueio) throw erroBloqueio;

      if (bloqueado) {
        await avisarNoLogin(
          "Acesso bloqueado",
          "Muitas tentativas erradas. Aguarde 15 minutos ou peça ao responsável para redefinir sua senha.",
        );
        return { sucesso: false };
      }

      // 2. Entrar pelo Supabase Auth
      const { error: erroLogin } = await supabase.auth.signInWithPassword({ email, password: senha });

      if (erroLogin) {
        await registrarTentativa(email, false, erroLogin.message);

        // 3a. Conta desativada pelo chefe: a Edge Function bloqueia o login
        //     no Supabase Auth, e ele responde com o código "user_banned".
        if (erroLogin.code === "user_banned") {
          await avisarNoLogin("Acesso negado", "Seu acesso está desativado. Fale com o responsável pela locadora.");
          return { sucesso: false };
        }

        // 3b. A mensagem é a mesma para e-mail que não existe e senha
        //     errada: assim ninguém descobre quais e-mails existem.
        await avisarNoLogin("Erro no login", "E-mail ou senha incorretos.");
        return { sucesso: false };
      }

      await registrarTentativa(email, true, null);

      // 4. Perfil + permissões. Se estiver desativado, o banco dá erro.
      const { data: perfil, error: erroSessao } = await supabase.rpc("iniciar_sessao", { p_plataforma: PLATAFORMA });

      if (erroSessao) {
        await supabase.auth.signOut();
        await avisarNoLogin("Acesso negado", erroSessao.message);
        return { sucesso: false };
      }

      // 5. Guarda na sessão. Se a senha for temporária (o chefe acabou de
      //    criar a conta ou redefinir), a tela de login abre a troca
      //    obrigatória antes de deixar entrar.
      sessao.usuario = perfil;
      console.log(`Login ok: ${perfil.nome} (${perfil.cargo})`);
      return { sucesso: true, trocarSenha: perfil.trocar_senha === true };
    } catch (erro) {
      console.error("Erro inesperado no login:", erro);
      await avisarNoLogin("Erro no login", "Não foi possível conectar ao servidor. Verifique a internet e tente de novo.");
      return { sucesso: false };
    }
  });

  // Entrega para as telas os dados de quem está logado
  ipcMain.handle("pedir-usuario-logado", async () => sessao.usuario);

  // ----------------------------------------------------- TROCAR SENHA
  ipcMain.handle("trocar-senha-logado", async (event, { senhaAtual, novaSenha }) => {
    const janela = obterJanelaTrocarSenha();
    const avisar = (tipo, titulo, mensagem) => mostrarAviso(janela, { tipo, titulo, mensagem });

    try {
      if (!sessao.usuario) {
        await avisar("erro", "Sessão expirada", "Entre no sistema de novo.");
        return { sucesso: false };
      }

      if (!senhaForte(novaSenha)) {
        await avisar("erro", "Senha fraca", "A nova senha precisa ter pelo menos 8 caracteres, com letras e números.");
        return { sucesso: false };
      }

      // Para conferir a senha atual, tentamos entrar com ela.
      // Se entrar, a senha está certa (e a sessão continua a mesma pessoa).
      const { error: erroConferir } = await supabase.auth.signInWithPassword({
        email: sessao.usuario.email,
        password: senhaAtual,
      });

      if (erroConferir) {
        await avisar("erro", "Senha incorreta", "A senha atual informada está incorreta.");
        return { sucesso: false };
      }

      if (!(await gravarNovaSenha(novaSenha, avisar))) return { sucesso: false };

      await avisar("sucesso", "Senha alterada", "Sua senha foi alterada com sucesso!");
      return { sucesso: true };
    } catch (erro) {
      console.error("Erro inesperado ao trocar senha:", erro);
      return { sucesso: false };
    }
  });

  // Grava a senha nova no Supabase Auth e avisa o banco. Usada pela troca
  // normal e pela obrigatória. Devolve true se deu certo.
  async function gravarNovaSenha(novaSenha, avisar) {
    const { error } = await supabase.auth.updateUser({ password: novaSenha });
    if (error) {
      console.error("Erro ao trocar senha:", error.message);
      const mensagem = /different|same/i.test(error.message)
        ? "A nova senha precisa ser diferente da senha atual."
        : "Não foi possível trocar sua senha. Tente novamente.";
      await avisar("erro", "Erro ao trocar senha", mensagem);
      return false;
    }

    // Tira a marca de "trocar senha" no banco e grava no histórico
    await supabase.rpc("senha_trocada");
    sessao.usuario.trocar_senha = false;
    return true;
  }

  // ------------------------------------------- TROCA OBRIGATÓRIA DE SENHA
  // Primeiro acesso com senha temporária: não pede a senha atual (a pessoa
  // acabou de entrar com ela). Só vale se o banco marcou trocar_senha.
  ipcMain.handle("trocar-senha-obrigatoria", async (event, { novaSenha }) => {
    const janela = obterJanelaTrocarSenha();
    const avisar = (tipo, titulo, mensagem) => mostrarAviso(janela, { tipo, titulo, mensagem });

    try {
      if (!sessao.usuario || !sessao.usuario.trocar_senha) return { sucesso: false };

      if (!senhaForte(novaSenha)) {
        await avisar("erro", "Senha fraca", "A nova senha precisa ter pelo menos 8 caracteres, com letras e números.");
        return { sucesso: false };
      }

      if (!(await gravarNovaSenha(novaSenha, avisar))) return { sucesso: false };

      await avisar("sucesso", "Senha criada", "Pronto! Use essa senha nos próximos acessos.");

      // Avisa a tela de login que pode seguir para o sistema
      const janelaLogin = obterJanelaPrincipal();
      if (janelaLogin && !janelaLogin.isDestroyed()) janelaLogin.webContents.send("senha-obrigatoria-trocada");
      return { sucesso: true };
    } catch (erro) {
      console.error("Erro inesperado na troca obrigatória:", erro);
      return { sucesso: false };
    }
  });

  // ------------------------------------------------------- MINHA CONTA
  // Cada pessoa muda o próprio nome. Cargo, e-mail e permissões só o chefe
  // muda (e o banco garante isso: ver tg_perfis_antes no script 01).
  ipcMain.handle("salvar-minha-conta", async (event, { nome }) => {
    const janela = obterJanelaDashboard();
    const avisar = (tipo, titulo, mensagem) => mostrarAviso(janela, { tipo, titulo, mensagem });

    if (!sessao.usuario) return { sucesso: false };

    const nomeLimpo = String(nome || "").trim().replace(/\s+/g, " ");
    if (nomeLimpo.length < 3 || nomeLimpo.length > 100) {
      await avisar("erro", "Nome inválido", "O nome precisa ter entre 3 e 100 caracteres.");
      return { sucesso: false };
    }

    const { error } = await supabase.from("perfis").update({ nome: nomeLimpo }).eq("id", sessao.usuario.id);
    if (error) {
      console.error("Erro ao salvar minha conta:", error.message);
      await avisar("erro", "Erro ao salvar", "Não foi possível salvar seus dados. Tente novamente.");
      return { sucesso: false };
    }

    sessao.usuario.nome = nomeLimpo;
    await avisar("sucesso", "Dados salvos", "Seu nome foi atualizado.");
    return { sucesso: true, usuario: sessao.usuario };
  });
}

module.exports = { registrarIpcSessao, senhaForte };
