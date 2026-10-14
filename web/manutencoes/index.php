<?php
/*
|--------------------------------------------------------------------------
| MANUTENÇÃO DE VEÍCULOS
|--------------------------------------------------------------------------
| Enquanto a manutenção estiver "Em andamento", o veículo fica com status
| "Em manutenção" e não aparece para aluguel.
*/

require __DIR__ . '/../includes/bootstrap.php';

exigir_permissao('manutencoes');

$abas = [
    'andamento'  => ['texto' => 'Na oficina', 'sql' => "m.status = 'Em andamento'"],
    'concluidas' => ['texto' => 'Concluídas', 'sql' => "m.status = 'Concluída'"],
    'todas'      => ['texto' => 'Todas',      'sql' => '1 = 1'],
];

$aba = $_GET['aba'] ?? 'andamento';

if (!isset($abas[$aba])) {
    $aba = 'andamento';
}

$contagem = [];

foreach ($abas as $chave => $info) {
    $contagem[$chave] = (int) db_valor("SELECT COUNT(*) FROM manutencoes m WHERE {$info['sql']}");
}

$manutencoes = db_todos(
    "SELECT m.*, v.marca, v.modelo, v.placa, u.nome AS aberto_por,
            DATEDIFF(COALESCE(m.data_liberacao, CURDATE()), m.data_entrada) AS dias_parado
     FROM manutencoes m
     JOIN veiculos v ON v.id = m.veiculo_id
     LEFT JOIN usuarios u ON u.id = m.usuario_id
     WHERE {$abas[$aba]['sql']}
     ORDER BY m.status = 'Concluída', m.data_entrada DESC"
);

$custoMes = (float) db_valor(
    "SELECT COALESCE(SUM(custo), 0) FROM manutencoes
     WHERE status = 'Concluída' AND data_liberacao >= DATE_FORMAT(CURDATE(), '%Y-%m-01')"
);

$titulo = 'Manutenção';
$subtitulo = 'Veículos na oficina e histórico de reparos';
$menu = 'manutencoes';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="page-header">
    <div>
        <h2>Manutenções</h2>
        <p>Gasto com manutenção neste mês: <strong><?= moeda($custoMes) ?></strong></p>
    </div>
    <a href="<?= e(url('manutencoes/cadastrar.php')) ?>" class="btn-primary">+ Enviar veículo para manutenção</a>
</div>

<nav class="abas">
    <?php foreach ($abas as $chave => $info): ?>
        <a href="<?= e(url('manutencoes/index.php?aba=' . $chave)) ?>" class="<?= $aba === $chave ? 'ativa' : '' ?>">
            <?= e($info['texto']) ?> <b><?= $contagem[$chave] ?></b>
        </a>
    <?php endforeach; ?>
</nav>

<div class="table-container">
    <table>
        <thead>
            <tr>
                <th>Veículo</th>
                <th>Defeito</th>
                <th>Oficina</th>
                <th>Entrada</th>
                <th>Previsão / Liberação</th>
                <th>Dias</th>
                <th class="numero">Custo</th>
                <th>Status</th>
                <th>Ações</th>
            </tr>
        </thead>
        <tbody>
            <?php foreach ($manutencoes as $m): ?>
                <?php $previsaoVencida = $m['status'] === 'Em andamento' && $m['previsao_liberacao'] && $m['previsao_liberacao'] < date('Y-m-d'); ?>
                <tr class="<?= $previsaoVencida ? 'linha-alerta' : '' ?>">
                    <td>
                        <a href="<?= e(url('veiculos/ver.php?id=' . $m['veiculo_id'])) ?>"><strong><?= e(nome_veiculo($m)) ?></strong></a><br>
                        <span class="texto-fraco"><?= e(formatar_placa($m['placa'])) ?></span>
                    </td>
                    <td>
                        <?= e($m['defeito']) ?>
                        <?php if ($m['locacao_id']): ?>
                            <br><small class="texto-fraco">Na devolução do aluguel #<?= (int) $m['locacao_id'] ?></small>
                        <?php endif; ?>
                        <?php if ($m['servico_realizado']): ?>
                            <br><small class="texto-fraco">Serviço: <?= e($m['servico_realizado']) ?></small>
                        <?php endif; ?>
                    </td>
                    <td><?= e($m['oficina'] ?? '—') ?></td>
                    <td><?= data_br($m['data_entrada']) ?></td>
                    <td>
                        <?php if ($m['status'] === 'Concluída'): ?>
                            <?= data_br($m['data_liberacao']) ?>
                        <?php else: ?>
                            <span class="<?= $previsaoVencida ? 'texto-vermelho' : '' ?>"><?= $m['previsao_liberacao'] ? 'prev. ' . data_br($m['previsao_liberacao']) : 'sem previsão' ?></span>
                        <?php endif; ?>
                    </td>
                    <td><?= (int) $m['dias_parado'] ?></td>
                    <td class="numero"><?= $m['custo'] !== null ? moeda($m['custo']) : '—' ?></td>
                    <td><?= badge_status($m['status']) ?></td>
                    <td>
                        <?php if ($m['status'] === 'Em andamento'): ?>
                            <a href="<?= e(url('manutencoes/concluir.php?id=' . $m['id'])) ?>" class="btn-small btn-success">Liberar veículo</a>
                        <?php else: ?>
                            <span class="texto-fraco">—</span>
                        <?php endif; ?>
                    </td>
                </tr>
            <?php endforeach; ?>

            <?php if (!$manutencoes): ?>
                <tr><td colspan="9" class="empty">Nenhuma manutenção nesta lista.</td></tr>
            <?php endif; ?>
        </tbody>
    </table>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
