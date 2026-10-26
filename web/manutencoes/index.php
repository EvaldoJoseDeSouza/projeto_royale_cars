<?php
/*
| MANUTENÇÃO DE VEÍCULOS
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/manutencoes.php';

exigir_permissao('manutencoes');

$aba = $_GET['aba'] ?? 'andamento';

if (!isset(ABAS_MANUTENCAO[$aba])) {
    $aba = 'andamento';
}

$contagem = [];

foreach (ABAS_MANUTENCAO as $chave => $info) {
    $contagem[$chave] = sb_contar('manutencoes', $info['filtro']);
}

$manutencoes = array_map('preparar_manutencao', sb_select('manutencoes', ABAS_MANUTENCAO[$aba]['filtro'] + [
    'select' => COLUNAS_MANUTENCAO,
    'order'  => 'status.asc,data_entrada.desc,id.desc',
]));

$custoMes = custo_manutencao_mes();

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
    <?php foreach (ABAS_MANUTENCAO as $chave => $info): ?>
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
                        <?php if ($vistoria = resumo_checklist($m)): ?>
                            <br><small class="<?= itens_com_problema($m) ? 'texto-vermelho' : 'texto-fraco' ?>">
                                Vistoria: <?= e($vistoria) ?><?= itens_com_problema($m) ? ' — problema em ' . e(itens_com_problema($m)) : '' ?>
                            </small>
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
