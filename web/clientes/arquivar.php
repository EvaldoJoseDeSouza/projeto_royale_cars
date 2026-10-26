<?php
/*
ARQUIVAR CLIENTE
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/clientes.php';

exigir_permissao('clientes_arquivar');
exigir_post();

$id = (int) ($_POST['id'] ?? 0);

[$cliente, $erro] = mudar_arquivado_cliente($id, true);

if ($erro) {
    flash('erro', $erro);
    redirecionar($id ? 'clientes/ver.php?id=' . $id : 'clientes/index.php');
}

flash('sucesso', "Cliente {$cliente['nome']} arquivado. Ele pode ser reativado em \"Clientes arquivados\".");
redirecionar('clientes/index.php');
