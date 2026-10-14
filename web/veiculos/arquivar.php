<?php
/*
|--------------------------------------------------------------------------
| ARQUIVAR VEÍCULO (substitui o antigo excluir.php)
|--------------------------------------------------------------------------
| Só veículos "Disponível" podem ser arquivados: um carro alugado ou na
| oficina precisa voltar antes.
*/

require __DIR__ . '/../includes/bootstrap.php';

exigir_permissao('veiculos_arquivar');
exigir_post();

$id = (int) ($_POST['id'] ?? 0);
$veiculo = db_linha('SELECT * FROM veiculos WHERE id = ?', [$id]);

if (!$veiculo || $veiculo['arquivado']) {
    flash('erro', 'Veículo não encontrado ou já arquivado.');
    redirecionar('veiculos/index.php');
}

if ($veiculo['status'] !== 'Disponível') {
    flash('erro', 'Só é possível arquivar veículos disponíveis. Este está: ' . $veiculo['status'] . '.');
    redirecionar('veiculos/ver.php?id=' . $id);
}

db_executar('UPDATE veiculos SET arquivado = 1, arquivado_em = NOW() WHERE id = ?', [$id]);

registrar_log('veiculos', 'arquivar', $id,
    'Arquivou o veículo ' . nome_veiculo($veiculo) . ' (' . formatar_placa($veiculo['placa']) . ').');

flash('sucesso', nome_veiculo($veiculo) . ' foi arquivado e saiu da frota.');
redirecionar('veiculos/index.php');
