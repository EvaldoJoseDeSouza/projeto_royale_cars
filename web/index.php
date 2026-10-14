<?php
/*
|--------------------------------------------------------------------------
| LOGIN
|--------------------------------------------------------------------------
| - Senha guardada com password_hash (nunca em texto puro).
| - Após 5 senhas erradas no mesmo e-mail, bloqueia por 15 minutos.
| - Usuário desativado pelo chefe não consegue entrar.
| - Toda tentativa fica registrada para o chefe consultar.
|
| Não existe mais "Criar uma conta" aqui: só o chefe cadastra usuários,
| pelo Painel Administrativo.
*/

require __DIR__ . '/includes/bootstrap.php';

if (usuario_logado()) {
    redirecionar('dashboard.php');
}

$erro = '';
$email = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verificar_csrf();

    $email = mb_strtolower(trim($_POST['email'] ?? ''));
    $senha = (string) ($_POST['senha'] ?? '');

    if ($email === '' || $senha === '') {
        $erro = 'Preencha o e-mail e a senha.';
    } elseif (login_bloqueado($email)) {
        registrar_tentativa($email, false, 'Bloqueado por excesso de tentativas');
        registrar_log('seguranca', 'login_bloqueado', null,
            "Login bloqueado por excesso de tentativas para {$email} (IP " . ip_cliente() . ').');

        $erro = 'Muitas tentativas erradas. Por segurança, aguarde ' . MINUTOS_BLOQUEIO . ' minutos e tente de novo.';
    } else {
        $usuario = db_linha('SELECT id, nome, email, senha, ativo FROM usuarios WHERE email = ?', [$email]);

        // Mesmo sem usuário, roda a verificação para o tempo de resposta ser igual
        $hash = $usuario['senha'] ?? '$2y$10$usesomesillystringfore7hnbRJHxXVLeakoG8K30oukPsA.ztMG';
        $senhaCorreta = password_verify($senha, $hash);

        if (!$usuario || !$senhaCorreta) {
            registrar_tentativa($email, false, $usuario ? 'Senha incorreta' : 'E-mail não cadastrado');
            $erro = 'E-mail ou senha incorretos.';
        } elseif (!$usuario['ativo']) {
            registrar_tentativa($email, false, 'Usuário desativado');
            registrar_log('seguranca', 'login_desativado', (int) $usuario['id'],
                "Usuário desativado tentou entrar: {$usuario['nome']}.");

            $erro = 'Seu acesso está desativado. Fale com o responsável pela locadora.';
        } else {
            // Nova identificação de sessão (evita roubo de sessão)
            session_regenerate_id(true);

            $_SESSION['usuario_id'] = (int) $usuario['id'];
            $_SESSION['ultima_atividade'] = time();

            if (password_needs_rehash($usuario['senha'], PASSWORD_DEFAULT)) {
                db_executar('UPDATE usuarios SET senha = ? WHERE id = ?',
                    [password_hash($senha, PASSWORD_DEFAULT), (int) $usuario['id']]);
            }

            db_executar('UPDATE usuarios SET ultimo_acesso = NOW() WHERE id = ?', [(int) $usuario['id']]);
            registrar_tentativa($email, true);
            registrar_log('seguranca', 'login', (int) $usuario['id'], 'Entrou no sistema.');

            redirecionar('dashboard.php');
        }
    }
}
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Royale Cars - Login</title>
    <link rel="stylesheet" href="<?= e(url('css/style.css')) ?>">
</head>
<body class="login-body">

<div class="login-container">
    <div class="login-card">

        <div class="login-logo">
            <h1>ROYALE <span>CARS</span></h1>
            <p>Sistema de Gestão</p>
        </div>

        <h2>Entrar</h2>

        <?= mostrar_flash() ?>

        <?php if ($erro): ?>
            <div class="alert-error"><?= e($erro) ?></div>
        <?php endif; ?>

        <form method="POST" novalidate>
            <?= csrf_campo() ?>

            <div class="form-group">
                <label for="email">E-mail</label>
                <input type="email" id="email" name="email" value="<?= e($email) ?>"
                       placeholder="Digite seu e-mail" autocomplete="username" required autofocus>
            </div>

            <div class="form-group">
                <label for="senha">Senha</label>
                <input type="password" id="senha" name="senha"
                       placeholder="Digite sua senha" autocomplete="current-password" required>
            </div>

            <button type="submit" class="btn-login">ENTRAR</button>
        </form>

        <p class="login-rodape">
            Esqueceu a senha? Peça ao chefe para redefinir seu acesso.
        </p>

    </div>
</div>

</body>
</html>
