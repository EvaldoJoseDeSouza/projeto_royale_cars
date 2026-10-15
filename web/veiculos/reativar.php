<?php
/*
| Reativa um veículo arquivado: ele volta para a frota como Disponível
| (o banco acerta o status sozinho).
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/veiculos.php';

exigir_permissao('veiculos_arquivar');
exigir_post();

$id = (int) ($_POST['id'] ?? 0);

[$veiculo, $erro] = mudar_arquivado_veiculo($id, false);

if ($erro) {
    flash('erro', $erro);
    redirecionar('veiculos/arquivados.php');
}

flash('sucesso', nome_veiculo($veiculo) . ' voltou para a frota.');
redirecionar('veiculos/ver.php?id=' . $id);
