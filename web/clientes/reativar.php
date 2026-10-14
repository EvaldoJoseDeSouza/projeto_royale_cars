<?php
/*
|--------------------------------------------------------------------------
| REATIVAR CLIENTE
|--------------------------------------------------------------------------
| Volta o cliente para a lista de ativos com todos os dados anteriores.
*/

require __DIR__ . '/../includes/bootstrap.php';

exigir_permissao('clientes_arquivar');
exigir_post();

$id = (int) ($_POST['id'] ?? 0);
$cliente = db_linha('SELECT id, nome, cnh_validade, arquivado FROM clientes WHERE id = ?', [$id]);

if (!$cliente || !$cliente['arquivado']) {
    flash('erro', 'Cliente não encontrado ou já está ativo.');
    redirecionar('clientes/clientes_arquivados.php');
}

db_executar('UPDATE clientes SET arquivado = 0, arquivado_em = NULL WHERE id = ?', [$id]);

registrar_log('clientes', 'reativar', $id, "Reativou o cliente {$cliente['nome']}.");

flash('sucesso', "Cliente {$cliente['nome']} reativado com os dados anteriores.");

if ($cliente['cnh_validade'] < date('Y-m-d')) {
    flash('aviso', 'A CNH deste cliente está vencida. Atualize a validade antes de um novo aluguel.');
}

redirecionar('clientes/ver.php?id=' . $id);
