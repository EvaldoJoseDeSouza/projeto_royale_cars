<?php
/*
|--------------------------------------------------------------------------
| ARQUIVAR CLIENTE
|--------------------------------------------------------------------------
| Não apaga nada: só marca como arquivado. O histórico de aluguéis
| continua guardado e o cliente pode ser reativado depois.
| Cliente com aluguel em andamento não pode ser arquivado.
*/

require __DIR__ . '/../includes/bootstrap.php';

exigir_permissao('clientes_arquivar');
exigir_post();

$id = (int) ($_POST['id'] ?? 0);
$cliente = db_linha('SELECT id, nome, cpf, arquivado FROM clientes WHERE id = ?', [$id]);

if (!$cliente || $cliente['arquivado']) {
    flash('erro', 'Cliente não encontrado ou já arquivado.');
    redirecionar('clientes/index.php');
}

$ativos = (int) db_valor(
    "SELECT COUNT(*) FROM locacoes WHERE cliente_id = ? AND status = 'Em andamento'",
    [$id]
);

if ($ativos > 0) {
    flash('erro', "{$cliente['nome']} tem aluguel em andamento. Registre a devolução antes de arquivar.");
    redirecionar('clientes/ver.php?id=' . $id);
}

db_executar('UPDATE clientes SET arquivado = 1, arquivado_em = NOW() WHERE id = ?', [$id]);

registrar_log('clientes', 'arquivar', $id,
    "Arquivou o cliente {$cliente['nome']} (CPF " . formatar_cpf($cliente['cpf']) . ').');

flash('sucesso', "Cliente {$cliente['nome']} arquivado. Ele pode ser reativado em \"Clientes arquivados\".");
redirecionar('clientes/index.php');
