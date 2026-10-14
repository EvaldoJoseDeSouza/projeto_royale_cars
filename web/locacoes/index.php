<?php
/*
|--------------------------------------------------------------------------
| ALUGUÉIS
|--------------------------------------------------------------------------
| Abas: em andamento, atrasados, finalizados, cancelados e todos.
*/

require __DIR__ . '/../includes/bootstrap.php';

exigir_permissao('locacoes_ver');

$abas = [
    'andamento'   => ['texto' => 'Em andamento', 'sql' => "l.status = 'Em andamento' AND l.data_prevista >= CURDATE()"],
    'atrasadas'   => ['texto' => 'Atrasados',    'sql' => "l.status = 'Em andamento' AND l.data_prevista < CURDATE()"],
    'finalizadas' => ['texto' => 'Finalizados',  'sql' => "l.status = 'Finalizada'"],
    'canceladas'  => ['texto' => 'Cancelados',   'sql' => "l.status = 'Cancelada'"],
    'todas'       => ['texto' => 'Todos',        'sql' => '1 = 1'],
];

$aba = $_GET['aba'] ?? 'andamento';

if (!isset($abas[$aba])) {
    $aba = 'andamento';
}

$busca = trim($_GET['busca'] ?? '');
$de = $_GET['de'] ?? '';
$ate = $_GET['ate'] ?? '';

$filtro = '1 = 1';
$parametros = [];

if ($busca !== '') {
    $filtro .= ' AND (c.nome LIKE ? OR v.marca LIKE ? OR v.modelo LIKE ? OR v.placa LIKE ? OR l.id = ?)';
    $placa = str_replace('-', '', strtoupper($busca));
    array_push($parametros, "%{$busca}%", "%{$busca}%", "%{$busca}%", "%{$placa}%", (int) ltrim($busca, '#'));
}

if (validar_data($de)) {
    $filtro .= ' AND l.data_retirada >= ?';
    $parametros[] = $de;
}

if (validar_data($ate)) {
    $filtro .= ' AND l.data_retirada <= ?';
    $parametros[] = $ate;
}

$base = 'FROM locacoes l
         JOIN clientes c ON c.id = l.cliente_id
         JOIN veiculos v ON v.id = l.veiculo_id';

$contagem = [];

foreach ($abas as $chave => $info) {
    $contagem[$chave] = (int) db_valor("SELECT COUNT(*) {$base} WHERE {$filtro} AND {$info['sql']}", $parametros);
}

[$limite, $offset, $pagina, $totalPaginas] = paginar($contagem[$aba]);

$ordem = in_array($aba, ['andamento', 'atrasadas'], true) ? 'l.data_prevista ASC' : 'l.id DESC';

$locacoes = db_todos(
    "SELECT l.*, c.nome AS cliente, c.telefone, v.marca, v.modelo, v.placa
     {$base}
     WHERE {$filtro} AND {$abas[$aba]['sql']}
     ORDER BY {$ordem}
     LIMIT {$limite} OFFSET {$offset}",
    $parametros
);

$titulo = 'Aluguéis';
$subtitulo = 'Retiradas, devoluções e atrasos';
$menu = 'locacoes';
require RAIZ . '/includes/cabecalho.php';

$filtrosAtuais = array_filter(['busca' => $busca, 'de' => $de, 'ate' => $ate]);
?>

<div class="page-header">
    <div>
        <h2>Aluguéis</h2>
        <p>Ao registrar um aluguel o carro fica indisponível; na devolução ele é liberado.</p>
    </div>

    <?php if (pode('locacoes_gerenciar')): ?>
        <a href="<?= e(url('locacoes/cadastrar.php')) ?>" class="btn-primary">+ Novo aluguel</a>
    <?php endif; ?>
</div>

<form method="GET" class="filtros">
    <input type="hidden" name="aba" value="<?= e($aba) ?>">
    <div class="filtro largo">
        <label for="busca">Buscar</label>
        <input type="text" id="busca" name="busca" value="<?= e($busca) ?>" placeholder="Cliente, veículo, placa ou nº do aluguel">
    </div>
    <div class="filtro">
        <label for="de">Retirada de</label>
        <input type="date" id="de" name="de" value="<?= e($de) ?>">
    </div>
    <div class="filtro">
        <label for="ate">até</label>
        <input type="date" id="ate" name="ate" value="<?= e($ate) ?>">
    </div>
    <button type="submit" class="btn-primary">Filtrar</button>
    <?php if ($filtrosAtuais): ?>
        <a href="<?= e(url('locacoes/index.php?aba=' . $aba)) ?>" class="btn-secondary">Limpar</a>
    <?php endif; ?>
</form>

<nav class="abas">
    <?php foreach ($abas as $chave => $info): ?>
        <a href="<?= e(url('locacoes/index.php?' . http_build_query(['aba' => $chave] + $filtrosAtuais))) ?>"
           class="<?= $aba === $chave ? 'ativa' : '' ?>">
            <?= e($info['texto']) ?> <b><?= $contagem[$chave] ?></b>
        </a>
    <?php endforeach; ?>
</nav>

<div class="table-container">
    <table>
        <thead>
            <tr>
                <th>#</th>
                <th>Cliente</th>
                <th>Veículo</th>
                <th>Retirada</th>
                <th>Devolução</th>
                <th class="numero">Valor</th>
                <th>Status</th>
                <th>Ações</th>
            </tr>
        </thead>
        <tbody>
            <?php foreach ($locacoes as $l): ?>
                <?php $status = status_locacao($l); ?>
                <tr class="<?= $status === 'Atrasada' ? 'linha-alerta' : '' ?>">
                    <td>#<?= $l['id'] ?></td>
                    <td>
                        <strong><?= e($l['cliente']) ?></strong><br>
                        <span class="texto-fraco"><?= e(formatar_telefone($l['telefone'])) ?></span>
                    </td>
                    <td>
                        <?= e(nome_veiculo($l)) ?><br>
                        <span class="texto-fraco nowrap"><?= e(formatar_placa($l['placa'])) ?></span>
                    </td>
                    <td><?= data_br($l['data_retirada']) ?></td>
                    <td>
                        <?php if ($l['data_devolucao']): ?>
                            <?= data_br($l['data_devolucao']) ?>
                        <?php else: ?>
                            <span class="<?= $status === 'Atrasada' ? 'texto-vermelho' : '' ?>">prevista <?= data_br($l['data_prevista']) ?></span>
                            <?php if ($status === 'Atrasada'): ?>
                                <br><small class="texto-vermelho"><?= dias_entre($l['data_prevista'], date('Y-m-d')) ?> dia(s) de atraso</small>
                            <?php endif; ?>
                        <?php endif; ?>
                    </td>
                    <td class="numero">
                        <?= moeda($l['status'] === 'Cancelada' ? $l['valor_previsto'] : $l['valor_total']) ?>
                        <?php if ($l['status'] === 'Em andamento'): ?><br><small class="texto-fraco">previsto</small><?php endif; ?>
                    </td>
                    <td><?= badge_status($status) ?></td>
                    <td>
                        <a href="<?= e(url('locacoes/ver.php?id=' . $l['id'])) ?>" class="btn-small btn-claro">Ver</a>
                        <?php if ($l['status'] === 'Em andamento' && pode('locacoes_gerenciar')): ?>
                            <a href="<?= e(url('locacoes/devolver.php?id=' . $l['id'])) ?>" class="btn-small btn-success">Devolução</a>
                        <?php endif; ?>
                    </td>
                </tr>
            <?php endforeach; ?>

            <?php if (!$locacoes): ?>
                <tr><td colspan="8" class="empty">Nenhum aluguel nesta lista.</td></tr>
            <?php endif; ?>
        </tbody>
    </table>
</div>

<?= links_paginacao($pagina, $totalPaginas) ?>

<?php require RAIZ . '/includes/rodape.php'; ?>
