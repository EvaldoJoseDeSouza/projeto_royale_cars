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

$filtros = [];

if ($soFalhas) {
    $filtros['sucesso'] = 'eq.false';
}

if ($email !== '') {
    $filtros['email'] = 'ilike.*' . trim(str_replace([',', '(', ')', '*', '"', '\\'], ' ', $email)) . '*';
}

$total = sb_contar('login_tentativas', $filtros);
[$limite, $offset, $pagina, $totalPaginas] = paginar($total, 30);

$tentativas = sb_select('login_tentativas', $filtros + [
    'select' => 'id,email,ip,sucesso,motivo,plataforma,criado_em',
    'order'  => 'id.desc',
    'limit'  => $limite,
    'offset' => $offset,
]);

// IPs com 3 ou mais falhas nos últimos 7 dias (agrupados aqui no PHP)
$porIp = [];

foreach (sb_select('login_tentativas', ['select' => 'ip,email,criado_em', 'sucesso' => 'eq.false',
                                        'criado_em' => 'gte.' . date('c', time() - 7 * 86400)]) as $t) {
    $ip = $t['ip'] ?? '?';
    $porIp[$ip]['ip'] = $ip;
    $porIp[$ip]['falhas'] = ($porIp[$ip]['falhas'] ?? 0) + 1;
    $porIp[$ip]['emails'][$t['email']] = true;
    $porIp[$ip]['ultima'] = max($porIp[$ip]['ultima'] ?? '', $t['criado_em']);
}

$suspeitos = array_filter($porIp, fn ($s) => $s['falhas'] >= 3);
usort($suspeitos, fn ($a, $b) => $b['falhas'] <=> $a['falhas']);
$suspeitos = array_slice($suspeitos, 0, 10);

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
                            <td class="numero"><?= count($s['emails']) ?></td>
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
            <tr><th>Data e hora</th><th>E-mail digitado</th><th>Onde</th><th>IP</th><th>Resultado</th><th>Motivo</th></tr>
        </thead>
        <tbody>
            <?php foreach ($tentativas as $t): ?>
                <tr>
                    <td><?= data_hora_br($t['criado_em']) ?></td>
                    <td><?= e($t['email']) ?></td>
                    <td><?= e(ucfirst($t['plataforma'] ?? '—')) ?></td>
                    <td><?= e($t['ip']) ?></td>
                    <td><?= $t['sucesso'] ? '<span class="status status-verde">Entrou</span>' : '<span class="status status-vermelho">Recusado</span>' ?></td>
                    <td><?= e($t['motivo'] ?? '—') ?></td>
                </tr>
            <?php endforeach; ?>

            <?php if (!$tentativas): ?>
                <tr><td colspan="6" class="empty">Nenhuma tentativa registrada.</td></tr>
            <?php endif; ?>
        </tbody>
    </table>
</div>

<?= links_paginacao($pagina, $totalPaginas) ?>

<?php require RAIZ . '/includes/rodape.php'; ?>
