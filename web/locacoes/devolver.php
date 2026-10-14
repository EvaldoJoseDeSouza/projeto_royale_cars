<?php
/*
|--------------------------------------------------------------------------
| REGISTRAR DEVOLUÇÃO (substitui o antigo finalizar.php)
|--------------------------------------------------------------------------
| - Calcula os dias usados e o atraso.
| - Libera o veículo, ou já envia para a manutenção se voltou com defeito.
| - Tudo numa transação: ou grava tudo, ou nada.
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/locacoes.php';

exigir_permissao('locacoes_gerenciar');

$id = (int) ($_GET['id'] ?? $_POST['id'] ?? 0);

$l = db_linha(
    'SELECT l.*, c.nome AS cliente, v.marca, v.modelo, v.placa
     FROM locacoes l
     JOIN clientes c ON c.id = l.cliente_id
     JOIN veiculos v ON v.id = l.veiculo_id
     WHERE l.id = ?',
    [$id]
);

if (!$l || $l['status'] !== 'Em andamento') {
    flash('erro', 'Aluguel não encontrado ou já encerrado.');
    redirecionar('locacoes/index.php');
}

$hoje = date('Y-m-d');
$erros = [];

$dados = [
    'data_devolucao'    => (string) ($_POST['data_devolucao'] ?? max($hoje, $l['data_retirada'])),
    'observacoes'       => trim((string) ($_POST['observacoes'] ?? '')),
    'enviar_manutencao' => !empty($_POST['enviar_manutencao']),
    'defeito'           => trim((string) ($_POST['defeito'] ?? '')),
    'oficina'           => trim((string) ($_POST['oficina'] ?? '')),
];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verificar_csrf();

    if (!validar_data($dados['data_devolucao'])) {
        $erros['data_devolucao'] = 'Informe a data da devolução.';
    } elseif ($dados['data_devolucao'] < $l['data_retirada']) {
        $erros['data_devolucao'] = 'A devolução não pode ser antes da retirada (' . data_br($l['data_retirada']) . ').';
    } elseif ($dados['data_devolucao'] > $hoje) {
        $erros['data_devolucao'] = 'A devolução não pode ser registrada com data futura.';
    }

    if ($dados['enviar_manutencao'] && mb_strlen($dados['defeito']) < 5) {
        $erros['defeito'] = 'Descreva o defeito encontrado.';
    }

    if (mb_strlen($dados['observacoes']) > 1000 || mb_strlen($dados['defeito']) > 1000 || mb_strlen($dados['oficina']) > 150) {
        $erros[] = 'Texto muito longo em algum campo.';
    }

    if (!$erros) {
        try {
            $resultado = em_transacao(function () use ($id, $dados) {
                $locacao = db_linha('SELECT * FROM locacoes WHERE id = ? FOR UPDATE', [$id]);

                if (!$locacao || $locacao['status'] !== 'Em andamento') {
                    throw new RegraNegocio('Este aluguel já foi encerrado por outra pessoa.');
                }

                $veiculo = db_linha('SELECT * FROM veiculos WHERE id = ? FOR UPDATE', [$locacao['veiculo_id']]);
                $calculo = calcular_devolucao($locacao, $dados['data_devolucao']);

                $observacoes = trim(implode("\n", array_filter([$locacao['observacoes'], $dados['observacoes'] !== '' ? 'Na devolução: ' . $dados['observacoes'] : null])));

                db_executar(
                    "UPDATE locacoes
                     SET status = 'Finalizada', data_devolucao = ?, dias_atraso = ?, valor_atraso = ?,
                         valor_total = ?, observacoes = ?, finalizado_por = ?, finalizado_em = NOW()
                     WHERE id = ?",
                    [
                        $dados['data_devolucao'], $calculo['dias_atraso'], $calculo['valor_atraso'],
                        $calculo['valor_total'], $observacoes !== '' ? $observacoes : null,
                        (int) $_SESSION['usuario_id'], $id,
                    ]
                );

                $descricao = "Registrou a devolução do aluguel #{$id}: " . nome_veiculo($veiculo) . ' (' . formatar_placa($veiculo['placa']) . '). '
                    . "{$calculo['dias']} diária(s), total " . moeda($calculo['valor_total'])
                    . ($calculo['dias_atraso'] ? ", com {$calculo['dias_atraso']} dia(s) de atraso" : '') . '.';

                registrar_log('locacoes', 'finalizar', $id, $descricao);

                if ($dados['enviar_manutencao']) {
                    db_executar(
                        "INSERT INTO manutencoes (veiculo_id, locacao_id, defeito, oficina, data_entrada, status, usuario_id)
                         VALUES (?, ?, ?, ?, ?, 'Em andamento', ?)",
                        [
                            $veiculo['id'], $id, $dados['defeito'],
                            $dados['oficina'] !== '' ? $dados['oficina'] : null,
                            $dados['data_devolucao'], (int) $_SESSION['usuario_id'],
                        ]
                    );

                    registrar_log('manutencoes', 'abrir', db_ultimo_id(),
                        'Enviou o ' . nome_veiculo($veiculo) . ' (' . formatar_placa($veiculo['placa']) . ") para manutenção na devolução: {$dados['defeito']}.");
                }

                // Volta a ficar disponível só se não houver reparo pendente
                $reparoPendente = (int) db_valor(
                    "SELECT COUNT(*) FROM manutencoes WHERE veiculo_id = ? AND status = 'Em andamento'",
                    [$veiculo['id']]
                );

                $novoStatus = $reparoPendente ? 'Em manutenção' : 'Disponível';
                db_executar('UPDATE veiculos SET status = ? WHERE id = ?', [$novoStatus, $veiculo['id']]);

                return [$calculo, $novoStatus];
            });

            [$calculo, $novoStatus] = $resultado;

            flash('sucesso', "Devolução registrada. Total: " . moeda($calculo['valor_total']) . ". Veículo agora: {$novoStatus}.");
            redirecionar('locacoes/ver.php?id=' . $id);
        } catch (RegraNegocio $e) {
            flash('erro', $e->getMessage());
            redirecionar('locacoes/ver.php?id=' . $id);
        }
    }
}

$titulo = 'Registrar devolução';
$subtitulo = 'Aluguel #' . $l['id'] . ' · ' . nome_veiculo($l) . ' · ' . $l['cliente'];
$menu = 'locacoes';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="form-container">
    <div class="page-header">
        <div>
            <h2>Devolução do veículo</h2>
            <p>
                Retirado em <strong><?= data_br($l['data_retirada']) ?></strong>,
                devolução prevista para <strong><?= data_br($l['data_prevista']) ?></strong>,
                diária de <strong><?= moeda($l['valor_diaria']) ?></strong>.
            </p>
        </div>
        <a href="<?= e(url('locacoes/ver.php?id=' . $id)) ?>" class="btn-secondary">Voltar</a>
    </div>

    <?= $erros ? mostrar_erros(array_unique(array_values($erros))) : '' ?>

    <form method="POST" novalidate data-calculo-devolucao
          data-diaria="<?= e($l['valor_diaria']) ?>"
          data-retirada="<?= e($l['data_retirada']) ?>"
          data-prevista="<?= e($l['data_prevista']) ?>"
          data-confirmar="Confirmar a devolução do <?= e(nome_veiculo($l)) ?>?">
        <?= csrf_campo() ?>
        <input type="hidden" name="id" value="<?= $id ?>">

        <div class="form-grid">
            <div class="form-group">
                <label for="data_devolucao">Data da devolução *</label>
                <input type="date" id="data_devolucao" name="data_devolucao" value="<?= e($dados['data_devolucao']) ?>"
                       min="<?= e($l['data_retirada']) ?>" max="<?= $hoje ?>"
                       class="<?= classe_erro($erros, 'data_devolucao') ?>" required>
                <?= erro_campo($erros, 'data_devolucao') ?>
            </div>

            <div class="form-group">
                <label for="observacoes">Observações da devolução</label>
                <input type="text" id="observacoes" name="observacoes" value="<?= e($dados['observacoes']) ?>"
                       maxlength="1000" placeholder="Ex.: tanque cheio, sem avarias">
            </div>
        </div>

        <div class="resumo-calculo">
            <div><span>Diárias cobradas</span><strong id="dev-dias">—</strong></div>
            <div><span>Atraso</span><strong id="dev-atraso">—</strong></div>
            <div><span>Total a cobrar</span><strong id="dev-total">—</strong></div>
        </div>

        <h3 class="secao-form">Estado do veículo</h3>

        <label class="checkbox">
            <input type="checkbox" id="enviar_manutencao" name="enviar_manutencao" value="1" <?= $dados['enviar_manutencao'] ? 'checked' : '' ?>>
            O veículo voltou com defeito — enviar direto para a manutenção (ele não poderá ser alugado até ser liberado)
        </label>

        <div id="area-manutencao" class="form-grid" style="margin-top: 14px;" hidden>
            <div class="form-group">
                <label for="defeito">Defeito encontrado *</label>
                <textarea id="defeito" name="defeito" maxlength="1000" class="<?= classe_erro($erros, 'defeito') ?>"
                          placeholder="Ex.: barulho na suspensão dianteira"><?= e($dados['defeito']) ?></textarea>
                <?= erro_campo($erros, 'defeito') ?>
            </div>
            <div class="form-group">
                <label for="oficina">Oficina</label>
                <input type="text" id="oficina" name="oficina" maxlength="150" value="<?= e($dados['oficina']) ?>"
                       placeholder="Opcional">
            </div>
        </div>

        <div class="form-actions">
            <button type="submit" class="btn-primary">Confirmar devolução</button>
            <a href="<?= e(url('locacoes/ver.php?id=' . $id)) ?>" class="btn-secondary">Cancelar</a>
        </div>
    </form>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
