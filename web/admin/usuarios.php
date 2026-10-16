<?php
/*
|--------------------------------------------------------------------------
| FUNCIONÁRIOS E GERENTES (exclusivo do chefe)
|--------------------------------------------------------------------------
| Cadastrar, editar permissões, ativar/desativar e redefinir senha.
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/usuarios.php';

exigir_chefe();

$cargo = $_GET['cargo'] ?? '';
$situacao = $_GET['situacao'] ?? '';

$filtros = [];

if (isset(CARGOS[$cargo])) {
    $filtros['cargo'] = 'eq.' . $cargo;
}

if ($situacao === 'ativos') {
    $filtros['ativo'] = 'eq.true';
} elseif ($situacao === 'inativos') {
    $filtros['ativo'] = 'eq.false';
}

$usuarios = listar_equipe($filtros);

// Senha temporária recém-criada (aparece uma única vez)
$senhaNova = $_SESSION['senha_temporaria'] ?? null;
unset($_SESSION['senha_temporaria']);

$totalPermissoes = count(todas_permissoes());

$titulo = 'Funcionários';
$subtitulo = 'Painel Administrativo';
$menu = 'admin';
require RAIZ . '/includes/cabecalho.php';
?>

<?php if ($senhaNova): ?>
    <div class="alert-success">
        <strong>Senha temporária de <?= e($senhaNova['nome']) ?>:</strong>
        <span class="senha-temporaria"><?= e($senhaNova['senha']) ?></span><br>
        Passe esta senha para a pessoa. Ela vai aparecer <strong>só agora</strong> e precisará ser trocada no primeiro acesso.
    </div>
<?php endif; ?>

<div class="page-header">
    <div>
        <h2>Equipe da locadora</h2>
        <p>Cada pessoa tem login próprio e só faz o que você liberar.</p>
    </div>

    <div class="acoes-topo">
        <a href="<?= e(url('admin/index.php')) ?>" class="btn-secondary">Voltar ao painel</a>
        <a href="<?= e(url('admin/usuario_form.php')) ?>" class="btn-primary">+ Cadastrar funcionário</a>
    </div>
</div>

<form method="GET" class="filtros">
    <div class="filtro">
        <label for="cargo">Cargo</label>
        <select id="cargo" name="cargo">
            <option value="">Todos</option>
            <?php foreach (CARGOS as $chave => $nome): ?>
                <option value="<?= e($chave) ?>" <?= $cargo === $chave ? 'selected' : '' ?>><?= e($nome) ?></option>
            <?php endforeach; ?>
        </select>
    </div>
    <div class="filtro">
        <label for="situacao">Situação</label>
        <select id="situacao" name="situacao">
            <option value="">Todos</option>
            <option value="ativos" <?= $situacao === 'ativos' ? 'selected' : '' ?>>Ativos</option>
            <option value="inativos" <?= $situacao === 'inativos' ? 'selected' : '' ?>>Desativados</option>
        </select>
    </div>
    <button type="submit" class="btn-primary">Filtrar</button>
</form>

<div class="table-container">
    <table>
        <thead>
            <tr>
                <th>Nome</th>
                <th>E-mail (login)</th>
                <th>Cargo</th>
                <th>Permissões</th>
                <th>Último acesso</th>
                <th>Situação</th>
                <th>Ações</th>
            </tr>
        </thead>
        <tbody>
            <?php foreach ($usuarios as $u): ?>
                <?php $ehChefe = $u['cargo'] === 'chefe'; ?>
                <tr>
                    <td>
                        <strong><?= e($u['nome']) ?></strong>
                        <?php if ($u['trocar_senha']): ?>
                            <br><small class="texto-fraco">aguardando troca de senha</small>
                        <?php endif; ?>
                    </td>
                    <td><?= e($u['email']) ?></td>
                    <td><?= e(CARGOS[$u['cargo']]) ?></td>
                    <td><?= $ehChefe ? 'Acesso total' : count($u['permissoes']) . ' de ' . $totalPermissoes ?></td>
                    <td><?= data_hora_br($u['ultimo_acesso']) ?></td>
                    <td><?= badge_status($u['ativo'] ? 'Ativo' : 'Inativo') ?></td>
                    <td>
                        <?php if ($ehChefe): ?>
                            <span class="texto-fraco">—</span>
                        <?php else: ?>
                            <a href="<?= e(url('admin/usuario_form.php?id=' . $u['id'])) ?>" class="btn-small">Editar</a>

                            <?= botao_acao('admin/redefinir_senha.php', ['id' => $u['id']], 'Redefinir senha', 'btn-small btn-claro',
                                'Gerar uma nova senha temporária para ' . $u['nome'] . '? A senha atual deixa de funcionar.') ?>

                            <?php if ($u['ativo']): ?>
                                <?= botao_acao('admin/usuario_status.php', ['id' => $u['id'], 'ativo' => 0], 'Desativar', 'btn-small btn-danger',
                                    'Desativar o acesso de ' . $u['nome'] . '? Ele será desconectado na hora.') ?>
                            <?php else: ?>
                                <?= botao_acao('admin/usuario_status.php', ['id' => $u['id'], 'ativo' => 1], 'Ativar', 'btn-small btn-success',
                                    'Reativar o acesso de ' . $u['nome'] . '?') ?>
                            <?php endif; ?>
                        <?php endif; ?>
                    </td>
                </tr>
            <?php endforeach; ?>

            <?php if (!$usuarios): ?>
                <tr><td colspan="7" class="empty">Nenhum usuário encontrado.</td></tr>
            <?php endif; ?>
        </tbody>
    </table>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
