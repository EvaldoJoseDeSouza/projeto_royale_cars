<?php
/*
|--------------------------------------------------------------------------
| ARQUIVAR CLIENTE
|--------------------------------------------------------------------------
| Não apaga nada: só marca como arquivado. O histórico de aluguéis
| continua guardado e o cliente pode ser reativado depois.
|
| Cliente com aluguel em andamento não pode ser arquivado: quem confere é
| o banco (a mesma regra vale no desktop e no celular). Se tiver, ele
| recusa com a frase pronta, que mostramos na tela.
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
