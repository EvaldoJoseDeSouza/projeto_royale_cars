<?php
/*
|--------------------------------------------------------------------------
| CANCELAR ALUGUEL
|--------------------------------------------------------------------------
| Para aluguel registrado por engano ou desistência. Nada é cobrado,
| o veículo é liberado e o motivo fica registrado.
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

try {
    em_transacao(function () use ($id, $motivo) {
        $locacao = db_linha('SELECT * FROM locacoes WHERE id = ? FOR UPDATE', [$id]);

        if (!$locacao || $locacao['status'] !== 'Em andamento') {
            throw new RegraNegocio('Só é possível cancelar aluguéis em andamento.');
        }

        $veiculo = db_linha('SELECT * FROM veiculos WHERE id = ? FOR UPDATE', [$locacao['veiculo_id']]);
        $observacoes = trim(($locacao['observacoes'] ?? '') . "\nCancelado: " . $motivo);

        db_executar(
            "UPDATE locacoes
             SET status = 'Cancelada', valor_total = 0, observacoes = ?, finalizado_por = ?, finalizado_em = NOW()
             WHERE id = ?",
            [$observacoes, (int) $_SESSION['usuario_id'], $id]
        );

        $reparoPendente = (int) db_valor(
            "SELECT COUNT(*) FROM manutencoes WHERE veiculo_id = ? AND status = 'Em andamento'",
            [$veiculo['id']]
        );

        db_executar('UPDATE veiculos SET status = ? WHERE id = ?',
            [$reparoPendente ? 'Em manutenção' : 'Disponível', $veiculo['id']]);

        registrar_log('locacoes', 'cancelar', $id,
            "Cancelou o aluguel #{$id} (" . nome_veiculo($veiculo) . '). Motivo: ' . $motivo);
    });

    flash('sucesso', "Aluguel #{$id} cancelado. O veículo foi liberado.");
} catch (RegraNegocio $e) {
    flash('erro', $e->getMessage());
}

redirecionar('locacoes/ver.php?id=' . $id);
