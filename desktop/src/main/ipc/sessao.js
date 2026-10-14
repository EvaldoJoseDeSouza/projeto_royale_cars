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
function registrarIpcSessao(deps) {
  const { mostrarAviso, obterJanelaPrincipal, obterJanelaTrocarSenha } = deps;

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
        // 3. Registra o erro. A mensagem é a mesma para e-mail que não
        //    existe e senha errada: assim ninguém descobre quais e-mails existem.
        await registrarTentativa(email, false, erroLogin.message);
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

      // 5. Guarda na sessão
      sessao.usuario = perfil;
      console.log(`Login ok: ${perfil.nome} (${perfil.cargo})`);
      return { sucesso: true };
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

      const { error: erroTroca } = await supabase.auth.updateUser({ password: novaSenha });
      if (erroTroca) {
        console.error("Erro ao trocar senha:", erroTroca.message);
        await avisar("erro", "Erro ao trocar senha", "Não foi possível trocar sua senha. Tente novamente.");
        return { sucesso: false };
      }

      // Avisa o banco: tira a marca de "trocar senha" e grava no histórico
      await supabase.rpc("senha_trocada");
      sessao.usuario.trocar_senha = false;

      await avisar("sucesso", "Senha alterada", "Sua senha foi alterada com sucesso!");
      return { sucesso: true };
    } catch (erro) {
      console.error("Erro inesperado ao trocar senha:", erro);
      return { sucesso: false };
    }
  });
}

module.exports = { registrarIpcSessao, senhaForte };
