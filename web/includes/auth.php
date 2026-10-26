<?php
/*
| AUTENTICAÇÃO E CONTROLE DE ACESSO (pelo Supabase)
*/

const MINUTOS_INATIVIDADE = 30; 
const MAX_FALHAS_EMAIL    = 5; 
const MINUTOS_BLOQUEIO    = 15; 
const PLATAFORMA          = 'web';

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
        $perfil = sb_linha('perfis', [
            'id'     => 'eq.' . $id,
            'select' => 'id,nome,email,cargo,ativo,trocar_senha,ultimo_acesso,criado_em,usuario_permissoes(permissao)',
        ]);
    } catch (SupabaseErro $e) {
        if ($e->codigo === 'sem_conexao') {
            pagina_sem_conexao();
        }
        $perfil = null; 
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
    sb_sair(); 

    $_SESSION = [];

    if (ini_get('session.use_cookies')) {
        $p = session_get_cookie_params();
        setcookie(session_name(), '', time() - 3600, $p['path'], $p['domain'], $p['secure'], $p['httponly']);
    }

    session_destroy();
    session_start();
}

function exigir_login(): array
{

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

    if ($usuario['trocar_senha'] && basename($_SERVER['SCRIPT_NAME']) !== 'alterar_senha.php') {
        redirecionar('alterar_senha.php');
    }

    return $usuario;
}

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

function entrar_no_sistema(string $email, string $senha): ?string
{
    try {
        if (sb_rpc('login_bloqueado', ['p_email' => $email], false)) {
            return 'Muitas tentativas erradas. Por segurança, aguarde ' . MINUTOS_BLOQUEIO
                 . ' minutos ou peça ao responsável para redefinir sua senha.';
        }

        try {
            sb_entrar($email, $senha);
        } catch (SupabaseErro $e) {
            if ($e->codigo === 'sem_conexao') {
                throw $e;
            }

            registrar_tentativa($email, false, $e->getMessage());

            if ($e->codigo === 'user_banned') {
                return 'Seu acesso está desativado. Fale com o responsável pela locadora.';
            }

            return 'E-mail ou senha incorretos.';
        }

        registrar_tentativa($email, true);

        try {
            sb_rpc('iniciar_sessao', ['p_plataforma' => PLATAFORMA]);
        } catch (SupabaseErro $e) {
            sb_sair();
            if ($e->codigo === 'sem_conexao') {
                throw $e;
            }
            return $e->getMessage(); 
        }
    } catch (SupabaseErro $e) {
        return 'Não foi possível conectar ao servidor. Verifique a internet e tente de novo.';
    }

    session_regenerate_id(true);
    $_SESSION['ultima_atividade'] = time();

    return null;
}

/* ========================================================================
   SENHA
   ======================================================================== */
function senha_atual_confere(string $email, string $senha): bool
{
    try {
        sb_entrar($email, $senha); 
        return true;
    } catch (SupabaseErro $e) {
        if ($e->codigo === 'sem_conexao') {
            throw $e;
        }
        return false;
    }
}

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
        error_log('Erro ao avisar senha_trocada: ' . $e->getMessage());
    }

    return null;
}
