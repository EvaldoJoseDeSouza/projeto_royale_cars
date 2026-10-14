<?php
/*
| Reativa um veículo arquivado: ele volta para a frota como Disponível.
*/

require __DIR__ . '/../includes/bootstrap.php';

exigir_permissao('veiculos_arquivar');
exigir_post();

$id = (int) ($_POST['id'] ?? 0);
$veiculo = db_linha('SELECT * FROM veiculos WHERE id = ?', [$id]);

if (!$veiculo || !$veiculo['arquivado']) {
    flash('erro', 'Veículo não encontrado ou já está na frota.');
    redirecionar('veiculos/arquivados.php');
}

db_executar("UPDATE veiculos SET arquivado = 0, arquivado_em = NULL, status = 'Disponível' WHERE id = ?", [$id]);

registrar_log('veiculos', 'reativar', $id,
    'Reativou o veículo ' . nome_veiculo($veiculo) . ' (' . formatar_placa($veiculo['placa']) . ').');

flash('sucesso', nome_veiculo($veiculo) . ' voltou para a frota.');
redirecionar('veiculos/ver.php?id=' . $id);
