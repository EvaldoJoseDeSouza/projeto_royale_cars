<?php
/*
|--------------------------------------------------------------------------
| ALTERAR SENHA
|--------------------------------------------------------------------------
| Usada de dois jeitos:
|  1) Obrigatória, quando o chefe redefiniu a senha (senha temporária).
|  2) Voluntária, pelo menu "Minha conta".
*/

require __DIR__ . '/includes/bootstrap.php';

$usuario = exigir_login();
$obrigatoria = (bool) $usuario['trocar_senha'];
$erros = [];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verificar_csrf();

    $atual = (string) ($_POST['senha_atual'] ?? '');
    $nova = (string) ($_POST['nova_senha'] ?? '');
    $confirmacao = (string) ($_POST['confirmar_senha'] ?? '');

    $hashAtual = db_valor('SELECT senha FROM usuarios WHERE id = ?', [(int) $usuario['id']]);

    if (!password_verify($atual, $hashAtual)) {
        $erros['senha_atual'] = 'A senha atual está incorreta.';
    }

    if ($erro = validar_senha($nova)) {
        $erros['nova_senha'] = $erro;
    } elseif (password_verify($nova, $hashAtual)) {
        $erros['nova_senha'] = 'A nova senha precisa ser diferente da atual.';
    }

    if ($nova !== $confirmacao) {
        $erros['confirmar_senha'] = 'As senhas não são iguais.';
    }

    if (!$erros) {
        db_executar('UPDATE usuarios SET senha = ?, trocar_senha = 0 WHERE id = ?',
            [password_hash($nova, PASSWORD_DEFAULT), (int) $usuario['id']]);

        registrar_log('usuarios', 'alterar_senha', (int) $usuario['id'], 'Alterou a própria senha.');

        session_regenerate_id(true);
        flash('sucesso', 'Senha alterada com sucesso.');
        redirecionar($obrigatoria ? 'dashboard.php' : 'configuracoes/index.php');
    }
}

$titulo = 'Alterar senha';
$subtitulo = $obrigatoria ? 'Crie uma senha pessoal para continuar' : 'Segurança da conta';
$menu = 'configuracoes';
require RAIZ . '/includes/cabecalho.php';
?>

<?php if ($obrigatoria): ?>
    <div class="alert-warning">
        Sua senha foi redefinida pelo chefe. Por segurança, crie uma senha nova antes de continuar.
    </div>
<?php endif; ?>

<div class="form-container" style="max-width: 560px;">
    <form method="POST">
        <?= csrf_campo() ?>

        <div class="form-group">
            <label for="senha_atual"><?= $obrigatoria ? 'Senha temporária' : 'Senha atual' ?></label>
            <input type="password" id="senha_atual" name="senha_atual" class="<?= classe_erro($erros, 'senha_atual') ?>"
                   autocomplete="current-password" required>
            <?= erro_campo($erros, 'senha_atual') ?>
        </div>

        <div class="form-group">
            <label for="nova_senha">Nova senha</label>
            <input type="password" id="nova_senha" name="nova_senha" data-validar="senha"
                   class="<?= classe_erro($erros, 'nova_senha') ?>" autocomplete="new-password" required>
            <small class="campo-ajuda">Mínimo de 8 caracteres, com letras e números.</small>
            <?= erro_campo($erros, 'nova_senha') ?>
        </div>

        <div class="form-group">
            <label for="confirmar_senha">Confirme a nova senha</label>
            <input type="password" id="confirmar_senha" name="confirmar_senha" data-confirma="nova_senha"
                   class="<?= classe_erro($erros, 'confirmar_senha') ?>" autocomplete="new-password" required>
            <?= erro_campo($erros, 'confirmar_senha') ?>
        </div>

        <div class="form-actions">
            <button type="submit" class="btn-primary">Salvar nova senha</button>
            <?php if (!$obrigatoria): ?>
                <a href="<?= e(url('configuracoes/index.php')) ?>" class="btn-secondary">Cancelar</a>
            <?php endif; ?>
        </div>
    </form>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
