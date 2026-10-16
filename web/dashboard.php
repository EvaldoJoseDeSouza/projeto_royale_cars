<?php
/*
|--------------------------------------------------------------------------
| DASHBOARD GERENCIAL
|--------------------------------------------------------------------------
| Cada pessoa vê os indicadores dos módulos a que tem acesso. Valores
| financeiros só aparecem para quem tem a permissão "financeiro".
*/

require __DIR__ . '/includes/bootstrap.php';
require RAIZ . '/includes/graficos.php';

$usuario = exigir_login();

$verFinanceiro = pode('financeiro');
$verLocacoes = pode('locacoes_ver');

$hoje = date('Y-m-d');

$frota = situacao_frota();
$totalFrota = array_sum($frota);
$ocupacao = $totalFrota ? round($frota['Alugado'] / $totalFrota * 100) : 0;

// Contagens: o banco devolve só o número (não baixa as linhas)
$alugueisAtivos = sb_contar('locacoes', ['status' => 'eq.Em andamento']);
$atrasados = sb_contar('locacoes', ['status' => 'eq.Em andamento', 'data_prevista' => 'lt.' . $hoje]);
$devolucoesHoje = sb_contar('locacoes', ['status' => 'eq.Em andamento', 'data_prevista' => 'eq.' . $hoje]);
$clientesAtivos = sb_contar('clientes', ['arquivado' => 'eq.false']);
$clientesNovosMes = sb_contar('clientes', ['criado_em' => 'gte.' . date('Y-m-01')]);

if ($verFinanceiro || $verLocacoes) {
    $mensal = dados_mensais(6);
}

if ($verFinanceiro) {
    $mesAtual = $mensal[date('Y-m')]['faturamento'];
    $mesAnterior = $mensal[date('Y-m', strtotime('first day of last month'))]['faturamento'] ?? 0;
    $variacao = $mesAnterior > 0 ? round(($mesAtual - $mesAnterior) / $mesAnterior * 100) : null;
}

$alertas = buscar_alertas();

$ultimas = $verLocacoes ? sb_select('vw_locacoes', [
    'select' => 'id,cliente_nome,marca,modelo,placa,data_retirada,data_prevista,data_devolucao,valor_total,status_exibicao',
    'order'  => 'id.desc',
    'limit'  => 6,
]) : [];

$titulo = 'Dashboard';
$subtitulo = 'Visão geral da Royale Cars';
$menu = 'dashboard';
require RAIZ . '/includes/cabecalho.php';

$primeiroNome = explode(' ', $usuario['nome'])[0];
?>

<div class="page-header">
    <div>
        <h2>Olá, <?= e($primeiroNome) ?>!</h2>
        <p>Resumo de hoje, <?= date('d/m/Y') ?>.</p>
    </div>

    <?php if (pode('locacoes_gerenciar')): ?>
        <a href="<?= e(url('locacoes/cadastrar.php')) ?>" class="btn-primary">+ Novo aluguel</a>
    <?php endif; ?>
</div>

<div class="dashboard-cards">

    <?php if ($verFinanceiro): ?>
        <a href="<?= e(url('financeiro/index.php')) ?>" class="dashboard-card verde">
            <div class="dashboard-card-icon"><?= icone('financeiro') ?></div>
            <div>
                <span>Faturamento do mês</span>
                <strong><?= moeda($mesAtual) ?></strong>
                <small>
                    <?php if ($variacao === null): ?>
                        sem base no mês anterior
                    <?php else: ?>
                        <?= $variacao >= 0 ? '▲' : '▼' ?> <?= abs($variacao) ?>% em relação a <?= mes_abreviado((int) date('n', strtotime('first day of last month'))) ?>
                    <?php endif; ?>
                </small>
            </div>
        </a>
    <?php endif; ?>

    <a href="<?= e(url($verLocacoes ? 'locacoes/index.php' : 'dashboard.php')) ?>" class="dashboard-card azul">
        <div class="dashboard-card-icon"><?= icone('locacoes') ?></div>
        <div>
            <span>Carros alugados agora</span>
            <strong><?= $alugueisAtivos ?></strong>
            <small><?= $devolucoesHoje ?> devolução(ões) prevista(s) para hoje</small>
        </div>
    </a>

    <a href="<?= e(url($verLocacoes ? 'locacoes/index.php?aba=atrasadas' : 'alertas.php')) ?>" class="dashboard-card <?= $atrasados ? 'vermelho' : 'verde' ?>">
        <div class="dashboard-card-icon"><?= icone('alerta') ?></div>
        <div>
            <span>Aluguéis em atraso</span>
            <strong><?= $atrasados ?></strong>
            <small><?= $atrasados ? 'precisam de contato com o cliente' : 'nenhum atraso' ?></small>
        </div>
    </a>

    <a href="<?= e(url(pode('clientes_ver') ? 'clientes/index.php' : 'dashboard.php')) ?>" class="dashboard-card">
        <div class="dashboard-card-icon"><?= icone('clientes') ?></div>
        <div>
            <span>Clientes ativos</span>
            <strong><?= $clientesAtivos ?></strong>
            <small><?= $clientesNovosMes ?> novo(s) neste mês</small>
        </div>
    </a>

    <?php if (!$verFinanceiro): ?>
        <a href="<?= e(url(pode('veiculos_ver') ? 'veiculos/index.php?status=Disponível' : 'dashboard.php')) ?>" class="dashboard-card verde">
            <div class="dashboard-card-icon"><?= icone('veiculos') ?></div>
            <div>
                <span>Veículos disponíveis</span>
                <strong><?= $frota['Disponível'] ?></strong>
                <small>de <?= $totalFrota ?> na frota</small>
            </div>
        </a>
    <?php endif; ?>

</div>

<div class="grade-2">

    <div class="bloco">
        <h2>Situação da frota</h2>
        <p class="texto-fraco"><?= $totalFrota ?> veículos ativos · ocupação de <strong><?= $ocupacao ?>%</strong></p>
        <?= barra_frota($frota) ?>
    </div>

    <div class="bloco">
        <div class="section-header" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
            <h2>Alertas</h2>
            <a href="<?= e(url('alertas.php')) ?>" class="btn-small btn-claro">Ver todos</a>
        </div>

        <ul class="lista-alertas">
            <?php foreach (TIPOS_ALERTA as $tipo => $info): ?>
                <?php if ($alertas[$tipo]): ?>
                    <li><span><span class="status <?= $info['cor'] ?>"><?= e($info['etiqueta']) ?></span>
                        <?= count($alertas[$tipo]) ?> · <?= e($info['titulo']) ?></span></li>
                <?php endif; ?>
            <?php endforeach; ?>
            <?php if (!array_filter($alertas)): ?>
                <li><span class="texto-fraco">Tudo em dia. Nenhum alerta no momento.</span></li>
            <?php endif; ?>
        </ul>
    </div>

</div>

<?php if (isset($mensal)): ?>
    <div class="bloco">
        <?php if ($verFinanceiro): ?>
            <h2>Faturamento dos últimos 6 meses</h2>
            <p class="texto-fraco" style="margin-bottom: 10px;">Valores dos aluguéis devolvidos em cada mês. O mês atual aparece em dourado.</p>
            <?= grafico_barras(array_map(fn ($m) => $m['faturamento'], $mensal)) ?>
        <?php else: ?>
            <h2>Aluguéis concluídos por mês</h2>
            <p class="texto-fraco" style="margin-bottom: 10px;">Quantidade de devoluções em cada mês. O mês atual aparece em dourado.</p>
            <?= grafico_barras(array_map(fn ($m) => $m['alugueis'], $mensal), false) ?>
        <?php endif; ?>
    </div>
<?php endif; ?>

<?php if ($verLocacoes): ?>
    <div class="bloco">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px;">
            <h2 style="margin: 0;">Últimos aluguéis</h2>
            <a href="<?= e(url('locacoes/index.php?aba=todas')) ?>" class="btn-primary">Ver todos</a>
        </div>

        <div class="table-container">
            <table>
                <thead>
                    <tr><th>#</th><th>Cliente</th><th>Veículo</th><th>Período</th><th class="numero">Valor</th><th>Status</th></tr>
                </thead>
                <tbody>
                    <?php foreach ($ultimas as $l): ?>
                        <tr>
                            <td><a href="<?= e(url('locacoes/ver.php?id=' . $l['id'])) ?>">#<?= $l['id'] ?></a></td>
                            <td><?= e($l['cliente_nome']) ?></td>
                            <td><?= e(nome_veiculo($l)) ?> <span class="texto-fraco"><?= e(formatar_placa($l['placa'])) ?></span></td>
                            <td><?= data_br($l['data_retirada']) ?> a <?= data_br($l['data_devolucao'] ?? $l['data_prevista']) ?></td>
                            <td class="numero"><?= moeda($l['valor_total']) ?></td>
                            <td><?= badge_status($l['status_exibicao']) ?></td>
                        </tr>
                    <?php endforeach; ?>
                    <?php if (!$ultimas): ?>
                        <tr><td colspan="6" class="empty">Nenhum aluguel registrado.</td></tr>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>
<?php endif; ?>

<?php require RAIZ . '/includes/rodape.php'; ?>
