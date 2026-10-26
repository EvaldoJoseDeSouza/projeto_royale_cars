<?php
/*
| REATIVAR CLIENTE
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/clientes.php';

exigir_permissao('clientes_arquivar');
exigir_post();

$id = (int) ($_POST['id'] ?? 0);

[$cliente, $erro] = mudar_arquivado_cliente($id, false);

if ($erro) {
    flash('erro', $erro);
    redirecionar('clientes/clientes_arquivados.php');
}

flash('sucesso', "Cliente {$cliente['nome']} reativado com os dados anteriores.");

if ($cliente['cnh_validade'] < date('Y-m-d')) {
    flash('aviso', 'A CNH deste cliente está vencida. Atualize a validade antes de um novo aluguel.');
}

redirecionar('clientes/ver.php?id=' . $id);
