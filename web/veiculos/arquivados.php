<?php
/*
|--------------------------------------------------------------------------
| VEÍCULOS ARQUIVADOS
|--------------------------------------------------------------------------
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/veiculos.php';

exigir_permissao('veiculos_ver');

$veiculos = listar_veiculos(true);
$alugueis = contar_alugueis_veiculos(array_column($veiculos, 'id'));

$titulo = 'Veículos arquivados';
$subtitulo = 'Fora da frota, com histórico preservado';
$menu = 'veiculos';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="page-header">
    <div>
        <h2>Veículos arquivados</h2>
        <p>Vendidos, devolvidos ao fornecedor ou fora de uso.</p>
    </div>
    <a href="<?= e(url('veiculos/index.php')) ?>" class="btn-secondary">Voltar para a frota</a>
</div>

<div class="table-container">
    <table>
        <thead>
            <tr><th></th><th>Veículo</th><th>Ano</th><th>Placa</th><th>Chassi</th><th>Aluguéis</th><th>Arquivado em</th><th>Ações</th></tr>
        </thead>
        <tbody>
            <?php foreach ($veiculos as $veiculo): ?>
                <tr>
                    <td><?= imagem_veiculo($veiculo) ?></td>
                    <td><strong><?= e(nome_veiculo($veiculo)) ?></strong></td>
                    <td><?= (int) $veiculo['ano'] ?></td>
                    <td><?= e(formatar_placa($veiculo['placa'])) ?></td>
                    <td class="texto-fraco"><?= e($veiculo['chassi']) ?></td>
                    <td><?= $alugueis[$veiculo['id']] ?? 0 ?></td>
                    <td><?= data_hora_br($veiculo['arquivado_em']) ?></td>
                    <td>
                        <a href="<?= e(url('veiculos/ver.php?id=' . $veiculo['id'])) ?>" class="btn-small btn-claro">Histórico</a>
                        <?php if (pode('veiculos_arquivar')): ?>
                            <?= botao_acao('veiculos/reativar.php', ['id' => $veiculo['id']], 'Reativar', 'btn-small btn-success',
                                'Colocar o ' . nome_veiculo($veiculo) . ' de volta na frota?') ?>
                        <?php endif; ?>
                    </td>
                </tr>
            <?php endforeach; ?>

            <?php if (!$veiculos): ?>
                <tr><td colspan="8" class="empty">Nenhum veículo arquivado.</td></tr>
            <?php endif; ?>
        </tbody>
    </table>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
