<?php
/*
|--------------------------------------------------------------------------
| CADASTRAR / EDITAR FUNCIONÁRIO OU GERENTE (exclusivo do chefe)
|--------------------------------------------------------------------------
| No cadastro, o sistema gera uma senha temporária que aparece uma única
| vez. No primeiro login a pessoa é obrigada a criar a própria senha.
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/usuarios.php';

exigir_chefe();

$id = (int) ($_GET['id'] ?? 0);
$editando = $id > 0;
$erros = [];

if ($editando) {
    $usuario = db_linha('SELECT * FROM usuarios WHERE id = ?', [$id]);

    if (!$usuario || $usuario['cargo'] === 'chefe') {
        flash('erro', 'Usuário não encontrado. (Os dados do chefe são alterados em "Minha conta".)');
        redirecionar('admin/usuarios.php');
    }

    $permissoesAntes = array_column(db_todos('SELECT permissao FROM usuario_permissoes WHERE usuario_id = ?', [$id]), 'permissao');
    $dados = $usuario + ['permissoes' => $permissoesAntes];
} else {
    $dados = ['nome' => '', 'email' => '', 'cargo' => 'funcionario', 'ativo' => 1, 'permissoes' => PERMISSOES_PADRAO['funcionario']];
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verificar_csrf();

    $dados['nome'] = trim(preg_replace('/\s+/', ' ', (string) ($_POST['nome'] ?? '')));
    $dados['email'] = mb_strtolower(trim((string) ($_POST['email'] ?? '')));
    $dados['cargo'] = (string) ($_POST['cargo'] ?? '');
    $dados['permissoes'] = limpar_permissoes((array) ($_POST['permissoes'] ?? []));

    if (!validar_nome_completo($dados['nome'])) {
        $erros['nome'] = 'Informe nome e sobrenome.';
    }

    if (!validar_email($dados['email'])) {
        $erros['email'] = 'Digite um e-mail válido.';
    } elseif (db_valor('SELECT id FROM usuarios WHERE email = ? AND id <> ?', [$dados['email'], $id])) {
        $erros['email'] = 'Já existe um usuário com este e-mail.';
    }

    // O cargo de chefe não pode ser dado por aqui
    if (!in_array($dados['cargo'], ['gerente', 'funcionario'], true)) {
        $erros['cargo'] = 'Escolha o cargo.';
    }

    if (!$dados['permissoes']) {
        $erros['permissoes'] = 'Marque pelo menos uma permissão.';
    }

    if (!$erros) {
        $conexao->begin_transaction();

        try {
            if ($editando) {
                db_executar('UPDATE usuarios SET nome = ?, email = ?, cargo = ? WHERE id = ?',
                    [$dados['nome'], $dados['email'], $dados['cargo'], $id]);

                salvar_permissoes($id, $dados['permissoes']);

                $mudancas = [];

                if ($usuario['nome'] !== $dados['nome']) { $mudancas[] = "nome: {$usuario['nome']} → {$dados['nome']}"; }
                if ($usuario['email'] !== $dados['email']) { $mudancas[] = "e-mail: {$usuario['email']} → {$dados['email']}"; }
                if ($usuario['cargo'] !== $dados['cargo']) { $mudancas[] = 'cargo: ' . CARGOS[$usuario['cargo']] . ' → ' . CARGOS[$dados['cargo']]; }
                if ($p = descrever_mudanca_permissoes($permissoesAntes, $dados['permissoes'])) { $mudancas[] = $p; }

                registrar_log('usuarios', 'editar', $id,
                    "Editou o acesso de {$dados['nome']}: " . ($mudancas ? implode('; ', $mudancas) : 'nenhuma alteração') . '.');

                $conexao->commit();
                flash('sucesso', "Acesso de {$dados['nome']} atualizado. As mudanças valem a partir da próxima página que ele abrir.");
            } else {
                $senha = gerar_senha_temporaria();

                db_executar(
                    'INSERT INTO usuarios (nome, email, senha, cargo, ativo, trocar_senha) VALUES (?, ?, ?, ?, 1, 1)',
                    [$dados['nome'], $dados['email'], password_hash($senha, PASSWORD_DEFAULT), $dados['cargo']]
                );

                $id = db_ultimo_id();
                salvar_permissoes($id, $dados['permissoes']);

                registrar_log('usuarios', 'cadastrar', $id,
                    'Cadastrou ' . mb_strtolower(CARGOS[$dados['cargo']]) . " {$dados['nome']} ({$dados['email']}) com "
                    . count($dados['permissoes']) . ' permissão(ões).');

                $conexao->commit();

                $_SESSION['senha_temporaria'] = ['nome' => $dados['nome'], 'senha' => $senha];
                flash('sucesso', "{$dados['nome']} cadastrado(a). Login: {$dados['email']}");
            }

            redirecionar('admin/usuarios.php');
        } catch (mysqli_sql_exception $e) {
            $conexao->rollback();

            if (campo_duplicado($e)) {
                $erros['email'] = 'Já existe um usuário com este e-mail.';
            } else {
                throw $e;
            }
        }
    }
}

$titulo = $editando ? 'Editar acesso' : 'Cadastrar funcionário';
$subtitulo = $editando ? $usuario['nome'] : 'Novo login individual';
$menu = 'admin';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="form-container">
    <div class="page-header">
        <div>
            <h2><?= $editando ? 'Dados e permissões' : 'Novo funcionário ou gerente' ?></h2>
            <p>
                <?= $editando
                    ? 'Para bloquear ou trocar a senha, use os botões na lista de funcionários.'
                    : 'Uma senha temporária será gerada. A pessoa cria a própria senha no primeiro acesso.' ?>
            </p>
        </div>
        <a href="<?= e(url('admin/usuarios.php')) ?>" class="btn-secondary">Voltar</a>
    </div>

    <?= $erros ? mostrar_erros(array_unique(array_values($erros))) : '' ?>

    <form method="POST" novalidate>
        <?= csrf_campo() ?>

        <div class="form-grid form-grid-3">
            <div class="form-group">
                <label for="nome">Nome completo *</label>
                <input type="text" id="nome" name="nome" value="<?= campo($dados, 'nome') ?>" maxlength="100"
                       data-validar="nome" class="<?= classe_erro($erros, 'nome') ?>" required>
                <?= erro_campo($erros, 'nome') ?>
            </div>

            <div class="form-group">
                <label for="email">E-mail (login) *</label>
                <input type="email" id="email" name="email" value="<?= campo($dados, 'email') ?>" maxlength="150"
                       data-validar="email" class="<?= classe_erro($erros, 'email') ?>" required>
                <?= erro_campo($erros, 'email') ?>
            </div>

            <div class="form-group">
                <label for="cargo">Cargo *</label>
                <select id="cargo" name="cargo" class="<?= classe_erro($erros, 'cargo') ?>" required>
                    <option value="funcionario" <?= $dados['cargo'] === 'funcionario' ? 'selected' : '' ?>>Funcionário</option>
                    <option value="gerente" <?= $dados['cargo'] === 'gerente' ? 'selected' : '' ?>>Gerente</option>
                </select>
                <?= erro_campo($erros, 'cargo') ?>
            </div>
        </div>

        <h3 class="secao-form">Permissões</h3>

        <p class="texto-fraco" style="margin-bottom: 12px;">
            Marque o que esta pessoa pode fazer.
            <button type="button" class="btn-small btn-claro" data-aplicar-cargo>Usar sugestão do cargo</button>
        </p>

        <?= erro_campo($erros, 'permissoes') ?>

        <div class="permissoes-grupos" data-permissoes
             data-padroes="<?= e(json_encode(PERMISSOES_PADRAO)) ?>"
             data-dependencias="<?= e(json_encode(PERMISSOES_DEPENDENTES)) ?>">
            <?php foreach (PERMISSOES as $grupo => $lista): ?>
                <div class="permissoes-grupo">
                    <h4><?= e($grupo) ?></h4>
                    <?php foreach ($lista as $chave => $texto): ?>
                        <label class="checkbox">
                            <input type="checkbox" name="permissoes[]" value="<?= e($chave) ?>"
                                <?= in_array($chave, $dados['permissoes'], true) ? 'checked' : '' ?>>
                            <?= e($texto) ?>
                        </label>
                    <?php endforeach; ?>
                </div>
            <?php endforeach; ?>

            <div class="permissoes-grupo" style="background: #f8f9fc;">
                <h4>Somente o chefe</h4>
                <p class="texto-fraco">Painel Administrativo: cadastrar pessoas, mudar permissões, redefinir senhas e ver o histórico de ações.</p>
            </div>
        </div>

        <div class="form-actions">
            <button type="submit" class="btn-primary"><?= $editando ? 'Salvar alterações' : 'Cadastrar e gerar senha' ?></button>
            <a href="<?= e(url('admin/usuarios.php')) ?>" class="btn-secondary">Cancelar</a>
        </div>
    </form>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
