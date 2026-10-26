<?php
/*
| FINANCEIRO
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/graficos.php';

exigir_permissao('financeiro');

$mensal = dados_mensais(12);
$mesAtual = $mensal[date('Y-m')];

$finalizadas = sb_select('locacoes', [
    'select' => 'cliente_id,veiculo_id,data_devolucao,valor_total,valor_atraso,clientes(nome),veiculos(marca,modelo,placa)',
    'status' => 'eq.Finalizada',
]);

$anoAtual = date('Y');
$faturamentoAno = 0.0;
$totais = ['faturamento' => 0.0, 'quantidade' => count($finalizadas), 'atrasos' => 0.0];
$porVeiculo = [];
$porCliente = [];

foreach ($finalizadas as $l) {
    $valor = (float) $l['valor_total'];
    $totais['faturamento'] += $valor;
    $totais['atrasos'] += (float) $l['valor_atraso'];

    if (str_starts_with($l['data_devolucao'], $anoAtual)) {
        $faturamentoAno += $valor;
    }

    $porVeiculo[$l['veiculo_id']] ??= ($l['veiculos'] ?? ['marca' => '—', 'modelo' => '', 'placa' => '']) + ['alugueis' => 0, 'faturado' => 0.0];
    $porVeiculo[$l['veiculo_id']]['alugueis']++;
    $porVeiculo[$l['veiculo_id']]['faturado'] += $valor;

    $porCliente[$l['cliente_id']] ??= ['nome' => $l['clientes']['nome'] ?? '—', 'alugueis' => 0, 'gasto' => 0.0];
    $porCliente[$l['cliente_id']]['alugueis']++;
    $porCliente[$l['cliente_id']]['gasto'] += $valor;
}

usort($porVeiculo, fn ($a, $b) => $b['faturado'] <=> $a['faturado']);
usort($porCliente, fn ($a, $b) => $b['gasto'] <=> $a['gasto']);
$rankingVeiculos = array_slice($porVeiculo, 0, 5);
$rankingClientes = array_slice($porCliente, 0, 5);

$emAndamento = sb_select('locacoes', ['select' => 'valor_previsto', 'status' => 'eq.Em andamento']);
$aReceber = (float) array_sum(array_column($emAndamento, 'valor_previsto'));

$ticketMedio = $totais['quantidade'] > 0 ? $totais['faturamento'] / $totais['quantidade'] : 0;
$resultadoMes = $mesAtual['faturamento'] - $mesAtual['manutencao'];

$titulo = 'Financeiro';
$subtitulo = 'Faturamento, custos e resultados';
$menu = 'financeiro';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="page-header">
    <div>
        <h2>Visão financeira</h2>
        <p>O faturamento conta no mês em que o veículo foi devolvido.</p>
    </div>

    <?php if (pode('relatorios_financeiros')): ?>
        <a href="<?= e(url('relatorios/index.php?tipo=faturamento')) ?>" class="btn-primary">Relatório detalhado</a>
    <?php endif; ?>
</div>

<div class="dashboard-cards">
    <div class="dashboard-card verde">
        <div class="dashboard-card-icon"><?= icone('financeiro') ?></div>
        <div>
            <span>Faturamento do mês</span>
            <strong><?= moeda($mesAtual['faturamento']) ?></strong>
            <small><?= $mesAtual['alugueis'] ?> aluguel(éis) concluído(s)</small>
        </div>
    </div>

    <div class="dashboard-card laranja">
        <div class="dashboard-card-icon"><?= icone('manutencao') ?></div>
        <div>
            <span>Manutenção no mês</span>
            <strong><?= moeda($mesAtual['manutencao']) ?></strong>
            <small>resultado do mês: <?= moeda($resultadoMes) ?></small>
        </div>
    </div>

    <div class="dashboard-card azul">
        <div class="dashboard-card-icon"><?= icone('locacoes') ?></div>
        <div>
            <span>Previsto a receber</span>
            <strong><?= moeda($aReceber) ?></strong>
            <small>aluguéis em andamento</small>
        </div>
    </div>

    <div class="dashboard-card">
        <div class="dashboard-card-icon"><?= icone('relatorios') ?></div>
        <div>
            <span>Faturamento em <?= date('Y') ?></span>
            <strong><?= moeda($faturamentoAno) ?></strong>
            <small>ticket médio <?= moeda($ticketMedio) ?></small>
        </div>
    </div>
</div>

<div class="bloco">
    <h2>Faturamento dos últimos 12 meses</h2>
    <p class="texto-fraco" style="margin-bottom: 10px;">Passe o mouse nas barras para ver o valor exato. O mês atual aparece em dourado.</p>
    <?= grafico_barras(array_map(fn ($m) => $m['faturamento'], $mensal)) ?>
</div>

<div class="bloco">
    <h2>Mês a mês</h2>
    <div class="table-container">
        <table>
            <thead>
                <tr>
                    <th>Mês</th>
                    <th class="numero">Aluguéis concluídos</th>
                    <th class="numero">Faturamento</th>
                    <th class="numero">Manutenção</th>
                    <th class="numero">Resultado</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach (array_reverse($mensal, true) as $mes => $m): ?>
                    <?php $resultado = $m['faturamento'] - $m['manutencao']; ?>
                    <tr>
                        <td><?= e(rotulo_mes($mes)) ?></td>
                        <td class="numero"><?= $m['alugueis'] ?></td>
                        <td class="numero"><?= moeda($m['faturamento']) ?></td>
                        <td class="numero"><?= moeda($m['manutencao']) ?></td>
                        <td class="numero <?= $resultado < 0 ? 'texto-vermelho' : '' ?>"><?= moeda($resultado) ?></td>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
    <p class="texto-fraco" style="margin-top: 10px;">
        Total histórico: <?= moeda($totais['faturamento']) ?> em <?= (int) $totais['quantidade'] ?> aluguéis,
        sendo <?= moeda($totais['atrasos']) ?> de diárias de atraso.
    </p>
</div>

<div class="grade-2">
    <div class="bloco">
        <h2>Veículos que mais faturaram</h2>
        <div class="table-container">
            <table>
                <thead><tr><th>Veículo</th><th class="numero">Aluguéis</th><th class="numero">Faturado</th></tr></thead>
                <tbody>
                    <?php foreach ($rankingVeiculos as $v): ?>
                        <tr>
                            <td><?= e(nome_veiculo($v)) ?> <span class="texto-fraco"><?= e(formatar_placa($v['placa'])) ?></span></td>
                            <td class="numero"><?= (int) $v['alugueis'] ?></td>
                            <td class="numero"><?= moeda($v['faturado']) ?></td>
                        </tr>
                    <?php endforeach; ?>
                    <?php if (!$rankingVeiculos): ?>
                        <tr><td colspan="3" class="empty">Sem dados ainda.</td></tr>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>

    <div class="bloco">
        <h2>Clientes que mais alugaram</h2>
        <div class="table-container">
            <table>
                <thead><tr><th>Cliente</th><th class="numero">Aluguéis</th><th class="numero">Total pago</th></tr></thead>
                <tbody>
                    <?php foreach ($rankingClientes as $c): ?>
                        <tr>
                            <td><?= e($c['nome']) ?></td>
                            <td class="numero"><?= (int) $c['alugueis'] ?></td>
                            <td class="numero"><?= moeda($c['gasto']) ?></td>
                        </tr>
                    <?php endforeach; ?>
                    <?php if (!$rankingClientes): ?>
                        <tr><td colspan="3" class="empty">Sem dados ainda.</td></tr>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
