<?php
/*
|--------------------------------------------------------------------------
| LOGIN
|--------------------------------------------------------------------------
| Quem confere a senha é o Supabase (o mesmo login do desktop e do
| celular). O roteiro completo está em includes/auth.php:
| entrar_no_sistema().
|
| - Após 5 senhas erradas no mesmo e-mail, o banco bloqueia por 15 minutos.
| - Usuário desativado pelo chefe não consegue entrar.
| - Toda tentativa fica registrada para o chefe consultar.
|
| Não existe "Criar uma conta" aqui: só o chefe cadastra usuários.
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
    } elseif (!validar_email($email)) {
        $erro = 'Entre com o seu e-mail de acesso.';
    } else {
        $erro = entrar_no_sistema($email, $senha) ?? '';

        if ($erro === '') {
            // Senha temporária? O exigir_login() do dashboard manda para a troca.
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
