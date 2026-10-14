<?php
/*
|--------------------------------------------------------------------------
| TENTATIVAS DE LOGIN (exclusivo do chefe)
|--------------------------------------------------------------------------
| Mostra entradas com sucesso e com erro, para identificar tentativas
| suspeitas (muitas senhas erradas, e-mails que não existem, usuários
| desativados tentando entrar).
*/

require __DIR__ . '/../includes/bootstrap.php';

exigir_chefe();

$soFalhas = !empty($_GET['falhas']);
$email = trim((string) ($_GET['email'] ?? ''));

$where = ['1 = 1'];
$p = [];

if ($soFalhas) {
    $where[] = 't.sucesso = 0';
}

if ($email !== '') {
    $where[] = 't.email LIKE ?';
    $p[] = "%{$email}%";
}

$sqlWhere = implode(' AND ', $where);
$total = (int) db_valor("SELECT COUNT(*) FROM login_tentativas t WHERE {$sqlWhere}", $p);
[$limite, $offset, $pagina, $totalPaginas] = paginar($total, 30);

$tentativas = db_todos(
    "SELECT t.* FROM login_tentativas t WHERE {$sqlWhere} ORDER BY t.id DESC LIMIT {$limite} OFFSET {$offset}",
    $p
);

// IPs com mais falhas nos últimos 7 dias
$suspeitos = db_todos(
    'SELECT ip, COUNT(*) AS falhas, COUNT(DISTINCT email) AS emails, MAX(criado_em) AS ultima
     FROM login_tentativas
     WHERE sucesso = 0 AND criado_em > DATE_SUB(NOW(), INTERVAL 7 DAY)
     GROUP BY ip
     HAVING falhas >= 3
     ORDER BY falhas DESC
     LIMIT 10'
);

$titulo = 'Tentativas de login';
$subtitulo = 'Painel Administrativo';
$menu = 'admin';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="page-header">
    <div>
        <h2>Acessos ao sistema</h2>
        <p>Após <?= MAX_FALHAS_EMAIL ?> senhas erradas o e-mail fica bloqueado por <?= MINUTOS_BLOQUEIO ?> minutos. Redefinir a senha libera na hora.</p>
    </div>
    <a href="<?= e(url('admin/logs.php')) ?>" class="btn-secondary">Histórico de ações</a>
</div>

<?php if ($suspeitos): ?>
    <div class="bloco">
        <h2>IPs com várias falhas (7 dias)</h2>
        <div class="table-container">
            <table>
                <thead><tr><th>IP</th><th class="numero">Falhas</th><th class="numero">E-mails tentados</th><th>Última tentativa</th></tr></thead>
                <tbody>
                    <?php foreach ($suspeitos as $s): ?>
                        <tr class="linha-alerta">
                            <td><?= e($s['ip']) ?></td>
                            <td class="numero"><?= (int) $s['falhas'] ?></td>
                            <td class="numero"><?= (int) $s['emails'] ?></td>
                            <td><?= data_hora_br($s['ultima']) ?></td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
<?php endif; ?>

<form method="GET" class="filtros">
    <div class="filtro largo">
        <label for="email">E-mail</label>
        <input type="text" id="email" name="email" value="<?= e($email) ?>">
    </div>
    <label class="checkbox" style="margin-bottom: 10px;">
        <input type="checkbox" name="falhas" value="1" <?= $soFalhas ? 'checked' : '' ?>> Só tentativas com erro
    </label>
    <button type="submit" class="btn-primary">Filtrar</button>
</form>

<div class="table-container">
    <table>
        <thead>
            <tr><th>Data e hora</th><th>E-mail digitado</th><th>IP</th><th>Resultado</th><th>Motivo</th></tr>
        </thead>
        <tbody>
            <?php foreach ($tentativas as $t): ?>
                <tr>
                    <td><?= data_hora_br($t['criado_em']) ?></td>
                    <td><?= e($t['email']) ?></td>
                    <td><?= e($t['ip']) ?></td>
                    <td><?= $t['sucesso'] ? '<span class="status status-verde">Entrou</span>' : '<span class="status status-vermelho">Recusado</span>' ?></td>
                    <td><?= e($t['motivo'] ?? '—') ?></td>
                </tr>
            <?php endforeach; ?>

            <?php if (!$tentativas): ?>
                <tr><td colspan="5" class="empty">Nenhuma tentativa registrada.</td></tr>
            <?php endif; ?>
        </tbody>
    </table>
</div>

<?= links_paginacao($pagina, $totalPaginas) ?>

<?php require RAIZ . '/includes/rodape.php'; ?>
