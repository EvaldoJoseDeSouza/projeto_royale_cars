<?php
/*
|--------------------------------------------------------------------------
| ARQUIVAR VEÍCULO
|--------------------------------------------------------------------------
| Só veículos "Disponível" podem ser arquivados: um carro alugado ou na
| oficina precisa voltar antes. Quem confere é o banco (a mesma regra vale
| no desktop e no celular); se não puder, ele recusa com a frase pronta.
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/veiculos.php';

exigir_permissao('veiculos_arquivar');
exigir_post();

$id = (int) ($_POST['id'] ?? 0);

[$veiculo, $erro] = mudar_arquivado_veiculo($id, true);

if ($erro) {
    flash('erro', $erro);
    redirecionar($id ? 'veiculos/ver.php?id=' . $id : 'veiculos/index.php');
}

flash('sucesso', nome_veiculo($veiculo) . ' foi arquivado e saiu da frota.');
redirecionar('veiculos/index.php');
