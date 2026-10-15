<?php
/*
|--------------------------------------------------------------------------
| MINHA CONTA
|--------------------------------------------------------------------------
| Cada usuário muda o próprio nome e vê suas permissões. Igual ao desktop:
| cargo, e-mail de acesso e permissões só o chefe muda (decisão 11 do
| plano), e o banco garante isso mesmo se alguém tentar burlar a tela.
*/

require __DIR__ . '/../includes/bootstrap.php';

$usuario = exigir_login();
$erros = [];
$dados = $usuario; // já vem do banco em usuario_logado()

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verificar_csrf();

    $dados['nome'] = trim(preg_replace('/\s+/', ' ', $_POST['nome'] ?? ''));
    $tamanho = mb_strlen($dados['nome']);

    // Mesma regra do banco (tabela perfis) e do desktop
    if ($tamanho < 3 || $tamanho > 100) {
        $erros['nome'] = 'O nome precisa ter entre 3 e 100 caracteres.';
    }

    if (!$erros) {
        try {
            sb_atualizar('perfis', ['id' => 'eq.' . $usuario['id']], ['nome' => $dados['nome']]);

            flash('sucesso', 'Seu nome foi atualizado.');
            redirecionar('configuracoes/index.php');
        } catch (SupabaseErro $e) {
            $erros['nome'] = sb_mensagem_erro($e);
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
                <label for="nome">Nome</label>
                <input type="text" id="nome" name="nome" value="<?= campo($dados, 'nome') ?>"
                       class="<?= classe_erro($erros, 'nome') ?>" minlength="3" maxlength="100" required>
                <?= erro_campo($erros, 'nome') ?>
            </div>

            <div class="form-group">
                <label for="email">E-mail de acesso</label>
                <input type="email" id="email" value="<?= campo($dados, 'email') ?>" disabled>
                <small class="campo-ajuda">Só o responsável pela locadora muda o e-mail de acesso.</small>
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
