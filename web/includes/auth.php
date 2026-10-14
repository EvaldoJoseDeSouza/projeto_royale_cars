<?php
/*
|--------------------------------------------------------------------------
| AUTENTICAÇÃO E CONTROLE DE ACESSO
|--------------------------------------------------------------------------
| A cada página aberta, o usuário é lido de novo do banco. Assim, se o
| chefe desativar alguém ou mudar suas permissões, vale na hora, sem
| esperar a pessoa sair do sistema.
*/

const MINUTOS_INATIVIDADE   = 30; // Sai sozinho depois de 30 min parado
const MAX_FALHAS_EMAIL      = 5;  // Bloqueia o e-mail após 5 senhas erradas...
const MAX_FALHAS_IP         = 15; // ...ou o IP após 15 tentativas erradas
const MINUTOS_BLOQUEIO      = 15; // ...pelos próximos 15 minutos

function usuario_logado(): ?array
{
    static $usuario = false;

    if ($usuario !== false) {
        return $usuario;
    }

    $usuario = null;
    $id = (int) ($_SESSION['usuario_id'] ?? 0);

    if ($id <= 0) {
        return null;
    }

    $dados = db_linha(
        'SELECT id, nome, email, cargo, ativo, trocar_senha FROM usuarios WHERE id = ?',
        [$id]
    );

    if (!$dados || !$dados['ativo']) {
        encerrar_sessao();
        flash('erro', 'Seu acesso foi desativado. Fale com o responsável pela locadora.');

        return null;
    }

    $dados['permissoes'] = array_column(
        db_todos('SELECT permissao FROM usuario_permissoes WHERE usuario_id = ?', [$id]),
        'permissao'
    );

    $usuario = $dados;

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

    // Senha temporária: precisa trocar antes de usar o sistema
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
    registrar_log('seguranca', 'acesso_negado', null,
        'Tentou abrir uma página sem permissão: ' . ($_SERVER['REQUEST_URI'] ?? '?'));

    http_response_code(403);

    $titulo = 'Acesso negado';
    $menu = '';
    require RAIZ . '/includes/cabecalho.php';
    ?>
    <div class="estado-vazio">
        <h2>Você não tem permissão para acessar esta página.</h2>
        <p>Se precisar deste acesso, peça ao chefe para liberar no Painel Administrativo.</p>
        <a href="<?= e(url('dashboard.php')) ?>" class="btn-primary">Voltar ao início</a>
    </div>
    <?php
    require RAIZ . '/includes/rodape.php';
    exit;
}


/* ========================================================================
   LOGIN E BLOQUEIO POR TENTATIVAS
   ======================================================================== */

function login_bloqueado(string $email): bool
{
    $falhasEmail = (int) db_valor(
        'SELECT COUNT(*) FROM login_tentativas
         WHERE email = ? AND sucesso = 0
           AND criado_em > DATE_SUB(NOW(), INTERVAL ' . MINUTOS_BLOQUEIO . ' MINUTE)',
        [$email]
    );

    $falhasIp = (int) db_valor(
        'SELECT COUNT(*) FROM login_tentativas
         WHERE ip = ? AND sucesso = 0
           AND criado_em > DATE_SUB(NOW(), INTERVAL ' . MINUTOS_BLOQUEIO . ' MINUTE)',
        [ip_cliente()]
    );

    return $falhasEmail >= MAX_FALHAS_EMAIL || $falhasIp >= MAX_FALHAS_IP;
}

function registrar_tentativa(string $email, bool $sucesso, ?string $motivo = null): void
{
    db_executar(
        'INSERT INTO login_tentativas (email, ip, sucesso, motivo) VALUES (?, ?, ?, ?)',
        [mb_substr($email, 0, 150), ip_cliente(), $sucesso, $motivo]
    );
}
