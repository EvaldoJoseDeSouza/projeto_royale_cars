<?php
/*
| CANCELAR ALUGUEL
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/locacoes.php';

exigir_permissao('locacoes_cancelar');
exigir_post();

$id = (int) ($_POST['id'] ?? 0);
$motivo = trim((string) ($_POST['motivo'] ?? ''));

if (mb_strlen($motivo) < 5 || mb_strlen($motivo) > 500) {
    flash('erro', 'Informe o motivo do cancelamento (de 5 a 500 caracteres).');
    redirecionar('locacoes/ver.php?id=' . $id);
}

[, $erros] = chamar_funcao_locacao('cancelar_aluguel', ['p_locacao_id' => $id, 'p_motivo' => $motivo]);

if ($erros) {
    flash('erro', reset($erros));
} else {
    flash('sucesso', "Aluguel #{$id} cancelado. O veículo foi liberado.");
}

redirecionar('locacoes/ver.php?id=' . $id);
