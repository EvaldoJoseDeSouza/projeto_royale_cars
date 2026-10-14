<?php
/*
|--------------------------------------------------------------------------
| MINHA CONTA
|--------------------------------------------------------------------------
| Cada usuário atualiza o próprio nome e e-mail e vê suas permissões.
| Cargo e permissões só o chefe muda, no Painel Administrativo.
*/

require __DIR__ . '/../includes/bootstrap.php';

$usuario = exigir_login();
$erros = [];
$dados = db_linha('SELECT nome, email, cargo, ultimo_acesso, criado_em FROM usuarios WHERE id = ?', [(int) $usuario['id']]);

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verificar_csrf();

    $dados['nome'] = trim(preg_replace('/\s+/', ' ', $_POST['nome'] ?? ''));
    $dados['email'] = mb_strtolower(trim($_POST['email'] ?? ''));

    if (!validar_nome_completo($dados['nome'])) {
        $erros['nome'] = 'Informe nome e sobrenome.';
    }

    if (!validar_email($dados['email'])) {
        $erros['email'] = 'Digite um e-mail válido.';
    } elseif (db_valor('SELECT id FROM usuarios WHERE email = ? AND id <> ?', [$dados['email'], (int) $usuario['id']])) {
        $erros['email'] = 'Este e-mail já está sendo usado por outra pessoa.';
    }

    if (!$erros) {
        try {
            db_executar('UPDATE usuarios SET nome = ?, email = ? WHERE id = ?',
                [$dados['nome'], $dados['email'], (int) $usuario['id']]);

            registrar_log('usuarios', 'editar', (int) $usuario['id'], 'Atualizou os próprios dados de conta.');
            flash('sucesso', 'Dados atualizados com sucesso!');
            redirecionar('configuracoes/index.php');
        } catch (mysqli_sql_exception $e) {
            if (campo_duplicado($e)) {
                $erros['email'] = 'Este e-mail já está sendo usado por outra pessoa.';
            } else {
                throw $e;
            }
        }
    }
}

$titulo = 'Minha conta';
$subtitulo = 'Seus dados de acesso';
$menu = 'configuracoes';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="grade-2">

    <div class="form-container">
        <h2 class="bloco-titulo">Dados pessoais</h2>

        <form method="POST">
            <?= csrf_campo() ?>

            <div class="form-group">
                <label for="nome">Nome completo</label>
                <input type="text" id="nome" name="nome" value="<?= campo($dados, 'nome') ?>"
                       data-validar="nome" class="<?= classe_erro($erros, 'nome') ?>" maxlength="100" required>
                <?= erro_campo($erros, 'nome') ?>
            </div>

            <div class="form-group">
                <label for="email">E-mail de acesso</label>
                <input type="email" id="email" name="email" value="<?= campo($dados, 'email') ?>"
                       data-validar="email" class="<?= classe_erro($erros, 'email') ?>" maxlength="150" required>
                <?= erro_campo($erros, 'email') ?>
            </div>

            <div class="form-actions">
                <button type="submit" class="btn-primary">Salvar alterações</button>
                <a href="<?= e(url('alterar_senha.php')) ?>" class="btn-secondary">Alterar senha</a>
            </div>
        </form>
    </div>

    <div class="bloco">
        <h2>Meu acesso</h2>

        <div class="ficha" style="grid-template-columns: 1fr 1fr; margin-bottom: 20px;">
            <div><span>Cargo</span><strong><?= e(CARGOS[$dados['cargo']]) ?></strong></div>
            <div><span>Último acesso</span><strong><?= data_hora_br($dados['ultimo_acesso']) ?></strong></div>
            <div><span>Conta criada em</span><strong><?= data_br($dados['criado_em']) ?></strong></div>
        </div>

        <h4 style="color: var(--azul); margin-bottom: 8px;">O que você pode fazer</h4>

        <?php if ($usuario['cargo'] === 'chefe'): ?>
            <p>Acesso total ao sistema, incluindo o Painel Administrativo.</p>
        <?php elseif (!$usuario['permissoes']): ?>
            <p class="texto-fraco">Nenhuma permissão liberada ainda.</p>
        <?php else: ?>
            <ul style="margin-left: 18px;">
                <?php foreach (todas_permissoes() as $permissao): ?>
                    <?php if (in_array($permissao, $usuario['permissoes'], true)): ?>
                        <li><?= e(nome_permissao($permissao)) ?></li>
                    <?php endif; ?>
                <?php endforeach; ?>
            </ul>
        <?php endif; ?>
    </div>

</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
