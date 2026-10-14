<?php
/*
|--------------------------------------------------------------------------
| FICHA DO VEÍCULO + HISTÓRICO DE ALUGUÉIS E MANUTENÇÕES
|--------------------------------------------------------------------------
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/veiculos.php';

exigir_permissao('veiculos_ver');

$id = (int) ($_GET['id'] ?? 0);
$veiculo = db_linha('SELECT * FROM veiculos WHERE id = ?', [$id]);

if (!$veiculo) {
    flash('erro', 'Veículo não encontrado.');
    redirecionar('veiculos/index.php');
}

$locacoes = db_todos(
    'SELECT l.*, c.nome AS cliente
     FROM locacoes l
     JOIN clientes c ON c.id = l.cliente_id
     WHERE l.veiculo_id = ?
     ORDER BY l.data_retirada DESC',
    [$id]
);

$manutencoes = db_todos(
    'SELECT * FROM manutencoes WHERE veiculo_id = ? ORDER BY data_entrada DESC',
    [$id]
);

$faturado = 0;
$diasAlugado = 0;

foreach ($locacoes as $l) {
    if ($l['status'] === 'Finalizada') {
        $faturado += $l['valor_total'];
        $diasAlugado += max(1, dias_entre($l['data_retirada'], $l['data_devolucao']));
    }
}

$custoManutencao = array_sum(array_column($manutencoes, 'custo'));

$titulo = nome_veiculo($veiculo);
$subtitulo = formatar_placa($veiculo['placa']) . ' · ' . $veiculo['ano'];
$menu = 'veiculos';
require RAIZ . '/includes/cabecalho.php';
?>

<?php if ($veiculo['arquivado']): ?>
    <div class="alert-warning">
        Veículo arquivado em <?= data_hora_br($veiculo['arquivado_em']) ?>. Ele não aparece na frota nem pode ser alugado.
    </div>
<?php endif; ?>

<div class="page-header">
    <div>
        <h2>Dados do veículo</h2>
        <p>Status: <?= badge_status($veiculo['status']) ?></p>
    </div>

    <div class="acoes-topo">
        <a href="<?= e(url($veiculo['arquivado'] ? 'veiculos/arquivados.php' : 'veiculos/index.php')) ?>" class="btn-secondary">Voltar</a>

        <?php if (!$veiculo['arquivado']): ?>
            <?php if ($veiculo['status'] === 'Disponível' && pode('locacoes_gerenciar')): ?>
                <a href="<?= e(url('locacoes/cadastrar.php?veiculo_id=' . $id)) ?>" class="btn-primary">Alugar</a>
            <?php endif; ?>

            <?php if ($veiculo['status'] === 'Disponível' && pode('manutencoes')): ?>
                <a href="<?= e(url('manutencoes/cadastrar.php?veiculo_id=' . $id)) ?>" class="btn-secondary">Enviar para manutenção</a>
            <?php endif; ?>

            <?php if (pode('veiculos_gerenciar')): ?>
                <a href="<?= e(url('veiculos/editar.php?id=' . $id)) ?>" class="btn-secondary">Editar</a>
            <?php endif; ?>
        <?php elseif (pode('veiculos_arquivar')): ?>
            <?= botao_acao('veiculos/reativar.php', ['id' => $id], 'Reativar veículo', 'btn-primary', 'Colocar este veículo de volta na frota?') ?>
        <?php endif; ?>
    </div>
</div>

<div class="grade-2">
    <div class="bloco">
        <?= imagem_veiculo($veiculo, 'foto-veiculo') ?>

        <div class="ficha" style="grid-template-columns: 1fr 1fr;">
            <div><span>Marca</span><strong><?= e($veiculo['marca']) ?></strong></div>
            <div><span>Modelo</span><strong><?= e($veiculo['modelo']) ?></strong></div>
            <div><span>Ano</span><strong><?= (int) $veiculo['ano'] ?></strong></div>
            <div><span>Placa</span><strong><?= e(formatar_placa($veiculo['placa'])) ?></strong></div>
            <div><span>Chassi</span><strong><?= e($veiculo['chassi']) ?></strong></div>
            <div><span>Diária</span><strong><?= moeda($veiculo['valor_diaria']) ?></strong></div>
        </div>
    </div>

    <div>
        <div class="dashboard-cards" style="grid-template-columns: 1fr;">
            <div class="dashboard-card verde">
                <div class="dashboard-card-icon"><?= icone('financeiro') ?></div>
                <div>
                    <span>Faturado com este veículo</span>
                    <strong><?= moeda($faturado) ?></strong>
                    <small><?= count($locacoes) ?> aluguel(éis), <?= $diasAlugado ?> diária(s) concluídas</small>
                </div>
            </div>

            <div class="dashboard-card laranja">
                <div class="dashboard-card-icon"><?= icone('manutencao') ?></div>
                <div>
                    <span>Gasto com manutenção</span>
                    <strong><?= moeda($custoManutencao) ?></strong>
                    <small><?= count($manutencoes) ?> manutenção(ões)</small>
                </div>
            </div>
        </div>
    </div>
</div>

<?php if (pode('locacoes_ver')): ?>
    <div class="bloco">
        <h2>Histórico de aluguéis</h2>
        <div class="table-container">
            <table>
                <thead>
                    <tr><th>#</th><th>Cliente</th><th>Retirada</th><th>Prevista</th><th>Devolvido</th><th class="numero">Valor</th><th>Status</th></tr>
                </thead>
                <tbody>
                    <?php foreach ($locacoes as $l): ?>
                        <tr>
                            <td><a href="<?= e(url('locacoes/ver.php?id=' . $l['id'])) ?>">#<?= $l['id'] ?></a></td>
                            <td><?= e($l['cliente']) ?></td>
                            <td><?= data_br($l['data_retirada']) ?></td>
                            <td><?= data_br($l['data_prevista']) ?></td>
                            <td><?= data_br($l['data_devolucao']) ?></td>
                            <td class="numero"><?= moeda($l['valor_total']) ?></td>
                            <td><?= badge_status(status_locacao($l)) ?></td>
                        </tr>
                    <?php endforeach; ?>
                    <?php if (!$locacoes): ?>
                        <tr><td colspan="7" class="empty">Nenhum aluguel ainda.</td></tr>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>
<?php endif; ?>

<div class="bloco">
    <h2>Histórico de manutenções</h2>
    <div class="table-container">
        <table>
            <thead>
                <tr><th>Entrada</th><th>Defeito</th><th>Oficina</th><th>Liberado em</th><th class="numero">Custo</th><th>Status</th></tr>
            </thead>
            <tbody>
                <?php foreach ($manutencoes as $m): ?>
                    <tr>
                        <td><?= data_br($m['data_entrada']) ?></td>
                        <td><?= e($m['defeito']) ?></td>
                        <td><?= e($m['oficina'] ?? '—') ?></td>
                        <td><?= data_br($m['data_liberacao']) ?></td>
                        <td class="numero"><?= $m['custo'] !== null ? moeda($m['custo']) : '—' ?></td>
                        <td><?= badge_status($m['status']) ?></td>
                    </tr>
                <?php endforeach; ?>
                <?php if (!$manutencoes): ?>
                    <tr><td colspan="6" class="empty">Nenhuma manutenção registrada.</td></tr>
                <?php endif; ?>
            </tbody>
        </table>
    </div>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
