<?php
/*
|--------------------------------------------------------------------------
| AUTENTICAÇÃO E CONTROLE DE ACESSO (pelo Supabase)
|--------------------------------------------------------------------------
| O login segue o MESMO roteiro nas 3 plataformas (plano de unificação):
|
|   1. Pergunta ao banco se o e-mail está bloqueado (5 erros em 15 min)
|   2. Tenta entrar pelo Supabase Auth (e-mail + senha)
|   3. Registra a tentativa (certa ou errada) para o painel do chefe
|   4. Pede ao banco o perfil e as permissões (iniciar_sessao)
|      - se a pessoa estiver desativada, o banco recusa e saímos
|
| Quem confere a senha é o Supabase: o PHP nunca vê nem guarda senha.
|
| A cada página aberta, o perfil é lido de novo do banco. Assim, se o chefe
| desativar alguém ou mudar suas permissões, vale na hora.
*/

const MINUTOS_INATIVIDADE = 30; // Sai sozinho depois de 30 min parado
const MAX_FALHAS_EMAIL    = 5;  // O banco bloqueia o e-mail após 5 senhas erradas...
const MINUTOS_BLOQUEIO    = 15; // ...por 15 minutos (regra de login_bloqueado, no banco)
const PLATAFORMA          = 'web';

/** Mesma regra de senha das 3 plataformas: 8+ caracteres, com letra e número. */
const REGRA_SENHA = 'A senha precisa ter pelo menos 8 caracteres, com letras e números.';

function usuario_logado(): ?array
{
    static $usuario = false;

    if ($usuario !== false) {
        return $usuario;
    }

    $usuario = null;
    $id = $_SESSION['supabase']['usuario_id'] ?? null;

    if (!$id) {
        return null;
    }

    try {
        // Uma pergunta só: o perfil e, "pendurada" nele, a lista de permissões
        $perfil = sb_linha('perfis', [
            'id'     => 'eq.' . $id,
            'select' => 'id,nome,email,cargo,ativo,trocar_senha,ultimo_acesso,criado_em,usuario_permissoes(permissao)',
        ]);
    } catch (SupabaseErro $e) {
        if ($e->codigo === 'sem_conexao') {
            pagina_sem_conexao();
        }
        $perfil = null; // token vencido ou recusado: precisa entrar de novo
    }

    if (!$perfil || !$perfil['ativo']) {
        encerrar_sessao();
        flash('erro', $perfil ? 'Seu acesso foi desativado. Fale com o responsável pela locadora.'
                              : 'Sua sessão terminou. Entre novamente.');

        return null;
    }

    $perfil['permissoes'] = array_column($perfil['usuario_permissoes'] ?? [], 'permissao');
    unset($perfil['usuario_permissoes']);

    $usuario = $perfil;

    return $usuario;
}

function eh_chefe(): bool
{
    $usuario = usuario_logado();

    return $usuario && $usuario['cargo'] === 'chefe';
}

/** O usuário logado tem a permissão? (o chefe tem todas) */
function pode(string $permissao): bool
{
    $usuario = usuario_logado();

    if (!$usuario) {
        return false;
    }

    return $usuario['cargo'] === 'chefe' || in_array($permissao, $usuario['permissoes'], true);
}

function encerrar_sessao(): void
{
    sb_sair(); // avisa o Supabase que este "crachá" não vale mais

    $_SESSION = [];

    if (ini_get('session.use_cookies')) {
        $p = session_get_cookie_params();
        setcookie(session_name(), '', time() - 3600, $p['path'], $p['domain'], $p['secure'], $p['httponly']);
    }

    session_destroy();
    session_start();
}

/** Coloque no topo de toda página interna. */
function exigir_login(): array
{
    // Tempo de inatividade
    if (isset($_SESSION['ultima_atividade'])
        && time() - $_SESSION['ultima_atividade'] > MINUTOS_INATIVIDADE * 60) {
        encerrar_sessao();
        flash('aviso', 'Sua sessão expirou por inatividade. Entre novamente.');
        redirecionar('index.php');
    }

    $_SESSION['ultima_atividade'] = time();

    $usuario = usuario_logado();

    if (!$usuario) {
        redirecionar('index.php');
    }

    // Senha temporária: precisa criar a própria senha antes de usar o sistema
    if ($usuario['trocar_senha'] && basename($_SERVER['SCRIPT_NAME']) !== 'alterar_senha.php') {
        redirecionar('alterar_senha.php');
    }

    return $usuario;
}

/** Bloqueia a página se o usuário não tiver NENHUMA das permissões. */
function exigir_permissao(string ...$permissoes): void
{
    exigir_login();

    foreach ($permissoes as $permissao) {
        if (pode($permissao)) {
            return;
        }
    }

    acesso_negado();
}

function exigir_chefe(): void
{
    exigir_login();

    if (!eh_chefe()) {
        acesso_negado();
    }
}

function acesso_negado(): void
{
    anotar_no_servidor('Tentou abrir uma página sem permissão: ' . ($_SERVER['REQUEST_URI'] ?? '?'));

    http_response_code(403);

    $titulo = 'Acesso negado';
    $menu = '';
    require RAIZ . '/includes/cabecalho.php';
    ?>
    <div class="estado-vazio">
        <h2>Você não tem permissão para acessar esta página.</h2>
        <p>Se precisar deste acesso, peça ao chefe para liberar na Administração.</p>
        <a href="<?= e(url('dashboard.php')) ?>" class="btn-primary">Voltar ao início</a>
    </div>
    <?php
    require RAIZ . '/includes/rodape.php';
    exit;
}

/** Sem internet (ou Supabase fora do ar): avisa em vez de "deslogar" a pessoa. */
function pagina_sem_conexao(): void
{
    http_response_code(503);
    ?>
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head>
        <meta charset="UTF-8">
        <title>Sem conexão - Royale Cars</title>
        <link rel="stylesheet" href="<?= e(url('css/style.css')) ?>">
    </head>
    <body class="login-body">
    <div class="login-container">
        <div class="login-card">
            <h2>Sem conexão com o servidor</h2>
            <div class="alert-error">Não foi possível falar com o banco de dados. Verifique a internet e tente de novo.</div>
            <a href="" class="btn-login" style="display:block; text-align:center;">TENTAR DE NOVO</a>
        </div>
    </div>
    </body>
    </html>
    <?php
    exit;
}


/* ========================================================================
   LOGIN
   ======================================================================== */

/** Grava a tentativa no banco. Se falhar, não pode impedir ninguém de entrar. */
function registrar_tentativa(string $email, bool $sucesso, ?string $motivo = null): void
{
    try {
        sb_rpc('registrar_tentativa_login', [
            'p_email'      => $email,
            'p_sucesso'    => $sucesso,
            'p_motivo'     => $motivo,
            'p_plataforma' => PLATAFORMA,
        ], false);
    } catch (SupabaseErro $e) {
        error_log('Erro ao registrar tentativa de login: ' . $e->getMessage());
    }
}

/**
 * Faz o login inteiro (os 4 passos lá do topo).
 * Devolve null se deu certo, ou a frase de erro para mostrar na tela.
 */
function entrar_no_sistema(string $email, string $senha): ?string
{
    try {
        // 1. Bloqueado por muitas tentativas?
        if (sb_rpc('login_bloqueado', ['p_email' => $email], false)) {
            return 'Muitas tentativas erradas. Por segurança, aguarde ' . MINUTOS_BLOQUEIO
                 . ' minutos ou peça ao responsável para redefinir sua senha.';
        }

        // 2. Entrar pelo Supabase Auth
        try {
            sb_entrar($email, $senha);
        } catch (SupabaseErro $e) {
            if ($e->codigo === 'sem_conexao') {
                throw $e;
            }

            // 3a. Errou: registra a tentativa
            registrar_tentativa($email, false, $e->getMessage());

            // Conta desativada pelo chefe: o Supabase responde "user_banned"
            if ($e->codigo === 'user_banned') {
                return 'Seu acesso está desativado. Fale com o responsável pela locadora.';
            }

            // A mesma frase para e-mail que não existe e senha errada:
            // assim ninguém descobre quais e-mails estão cadastrados.
            return 'E-mail ou senha incorretos.';
        }

        // 3b. Acertou
        registrar_tentativa($email, true);

        // 4. Perfil e permissões. Se estiver desativado, o banco recusa.
        try {
            sb_rpc('iniciar_sessao', ['p_plataforma' => PLATAFORMA]);
        } catch (SupabaseErro $e) {
            sb_sair();
            if ($e->codigo === 'sem_conexao') {
                throw $e;
            }
            return $e->getMessage(); // ex.: "Seu acesso está desativado..."
        }
    } catch (SupabaseErro $e) {
        return 'Não foi possível conectar ao servidor. Verifique a internet e tente de novo.';
    }

    // Nova identificação de sessão (evita roubo de sessão).
    // O "crachá" do Supabase já está em $_SESSION['supabase'] (sb_entrar guardou).
    session_regenerate_id(true);
    $_SESSION['ultima_atividade'] = time();

    return null;
}

/* ========================================================================
   SENHA
   ======================================================================== */

/** Confere a senha atual tentando entrar com ela (o Supabase não tem outro jeito). */
function senha_atual_confere(string $email, string $senha): bool
{
    try {
        sb_entrar($email, $senha); // se entrar, renova o crachá da mesma pessoa
        return true;
    } catch (SupabaseErro $e) {
        if ($e->codigo === 'sem_conexao') {
            throw $e;
        }
        return false;
    }
}

/**
 * Grava a senha nova no Supabase Auth e avisa o banco (tira a marca de
 * "trocar senha" e grava no histórico). Devolve null ou a frase de erro.
 */
function gravar_nova_senha(string $novaSenha): ?string
{
    try {
        sb_trocar_senha($novaSenha);
    } catch (SupabaseErro $e) {
        if ($e->codigo === 'same_password') {
            return 'A nova senha precisa ser diferente da atual.';
        }
        if ($e->codigo === 'weak_password') {
            return REGRA_SENHA;
        }
        return $e->codigo === 'sem_conexao'
            ? 'Não foi possível conectar ao servidor. Verifique a internet e tente de novo.'
            : 'Não foi possível trocar sua senha. Tente novamente.';
    }

    try {
        sb_rpc('senha_trocada');
    } catch (SupabaseErro $e) {
        // A senha já mudou. Se só a marca falhar, na próxima tela ele pede de novo.
        error_log('Erro ao avisar senha_trocada: ' . $e->getMessage());
    }

    return null;
}
