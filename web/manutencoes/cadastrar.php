<?php
/*
|--------------------------------------------------------------------------
| ENVIAR VEÍCULO PARA MANUTENÇÃO
|--------------------------------------------------------------------------
| Só veículos disponíveis. (Carro alugado vai para a manutenção na hora da
| devolução, marcando "voltou com defeito".)
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/locacoes.php';

exigir_permissao('manutencoes');

$hoje = date('Y-m-d');
$erros = [];

$dados = [
    'veiculo_id'         => (int) ($_POST['veiculo_id'] ?? $_GET['veiculo_id'] ?? 0),
    'defeito'            => trim((string) ($_POST['defeito'] ?? '')),
    'oficina'            => trim((string) ($_POST['oficina'] ?? '')),
    'data_entrada'       => (string) ($_POST['data_entrada'] ?? $hoje),
    'previsao_liberacao' => (string) ($_POST['previsao_liberacao'] ?? ''),
];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verificar_csrf();

    if ($dados['veiculo_id'] <= 0) {
        $erros['veiculo_id'] = 'Selecione o veículo.';
    }

    if (mb_strlen($dados['defeito']) < 5 || mb_strlen($dados['defeito']) > 1000) {
        $erros['defeito'] = 'Descreva o defeito ou o serviço (mínimo 5 caracteres).';
    }

    if (mb_strlen($dados['oficina']) > 150) {
        $erros['oficina'] = 'Nome da oficina muito longo.';
    }

    if (!validar_data($dados['data_entrada']) || $dados['data_entrada'] > $hoje) {
        $erros['data_entrada'] = 'Data de entrada inválida (não pode ser no futuro).';
    } elseif ($dados['data_entrada'] < date('Y-m-d', strtotime('-30 days'))) {
        $erros['data_entrada'] = 'A data de entrada não pode ser de mais de 30 dias atrás.';
    }

    if ($dados['previsao_liberacao'] !== '') {
        if (!validar_data($dados['previsao_liberacao'])) {
            $erros['previsao_liberacao'] = 'Data de previsão inválida.';
        } elseif (!isset($erros['data_entrada']) && $dados['previsao_liberacao'] < $dados['data_entrada']) {
            $erros['previsao_liberacao'] = 'A previsão não pode ser antes da entrada.';
        }
    }

    if (!$erros) {
        try {
            $id = em_transacao(function () use ($dados) {
                $veiculo = db_linha('SELECT * FROM veiculos WHERE id = ? FOR UPDATE', [$dados['veiculo_id']]);

                if (!$veiculo || $veiculo['arquivado']) {
                    throw new RegraNegocio('Veículo não encontrado.');
                }

                if ($veiculo['status'] !== 'Disponível') {
                    throw new RegraNegocio(nome_veiculo($veiculo) . ' está "' . $veiculo['status'] . '". Só veículos disponíveis podem ir para a oficina por aqui.');
                }

                db_executar(
                    "INSERT INTO manutencoes (veiculo_id, defeito, oficina, data_entrada, previsao_liberacao, status, usuario_id)
                     VALUES (?, ?, ?, ?, ?, 'Em andamento', ?)",
                    [
                        $veiculo['id'], $dados['defeito'],
                        $dados['oficina'] !== '' ? $dados['oficina'] : null,
                        $dados['data_entrada'],
                        $dados['previsao_liberacao'] !== '' ? $dados['previsao_liberacao'] : null,
                        (int) $_SESSION['usuario_id'],
                    ]
                );

                $id = db_ultimo_id();

                db_executar("UPDATE veiculos SET status = 'Em manutenção' WHERE id = ?", [$veiculo['id']]);

                registrar_log('manutencoes', 'abrir', $id,
                    'Enviou o ' . nome_veiculo($veiculo) . ' (' . formatar_placa($veiculo['placa']) . ") para manutenção: {$dados['defeito']}.");

                return $id;
            });

            flash('sucesso', 'Veículo enviado para manutenção. Ele não poderá ser alugado até ser liberado.');
            redirecionar('manutencoes/index.php');
        } catch (RegraNegocio $e) {
            $erros['veiculo_id'] = $e->getMessage();
        }
    }
}

$veiculos = db_todos(
    "SELECT id, marca, modelo, placa FROM veiculos
     WHERE arquivado = 0 AND status = 'Disponível'
     ORDER BY marca, modelo"
);

$titulo = 'Enviar para manutenção';
$subtitulo = 'O veículo fica bloqueado para aluguel';
$menu = 'manutencoes';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="form-container">
    <div class="page-header">
        <div>
            <h2>Nova manutenção</h2>
            <p>Veículos alugados vão para a manutenção na hora da devolução.</p>
        </div>
        <a href="<?= e(url('manutencoes/index.php')) ?>" class="btn-secondary">Voltar</a>
    </div>

    <?= $erros ? mostrar_erros(array_unique(array_values($erros))) : '' ?>

    <form method="POST" novalidate>
        <?= csrf_campo() ?>

        <div class="form-grid">
            <div class="form-group inteiro">
                <label for="veiculo_id">Veículo *</label>
                <select id="veiculo_id" name="veiculo_id" class="<?= classe_erro($erros, 'veiculo_id') ?>" required>
                    <option value="">Selecione um veículo disponível</option>
                    <?php foreach ($veiculos as $v): ?>
                        <option value="<?= $v['id'] ?>" <?= $dados['veiculo_id'] === (int) $v['id'] ? 'selected' : '' ?>>
                            <?= e(nome_veiculo($v)) ?> — <?= e(formatar_placa($v['placa'])) ?>
                        </option>
                    <?php endforeach; ?>
                </select>
                <?= erro_campo($erros, 'veiculo_id') ?>
            </div>

            <div class="form-group inteiro">
                <label for="defeito">Defeito ou serviço *</label>
                <textarea id="defeito" name="defeito" maxlength="1000" class="<?= classe_erro($erros, 'defeito') ?>"
                          placeholder="Ex.: revisão dos 20.000 km, troca de pneus, barulho no motor..." required><?= e($dados['defeito']) ?></textarea>
                <?= erro_campo($erros, 'defeito') ?>
            </div>

            <div class="form-group">
                <label for="oficina">Oficina</label>
                <input type="text" id="oficina" name="oficina" maxlength="150" value="<?= e($dados['oficina']) ?>" placeholder="Opcional">
                <?= erro_campo($erros, 'oficina') ?>
            </div>

            <div class="form-group">
                <label for="data_entrada">Data de entrada na oficina *</label>
                <input type="date" id="data_entrada" name="data_entrada" value="<?= e($dados['data_entrada']) ?>" max="<?= $hoje ?>"
                       class="<?= classe_erro($erros, 'data_entrada') ?>" required>
                <?= erro_campo($erros, 'data_entrada') ?>
            </div>

            <div class="form-group">
                <label for="previsao_liberacao">Previsão de liberação</label>
                <input type="date" id="previsao_liberacao" name="previsao_liberacao" value="<?= e($dados['previsao_liberacao']) ?>"
                       min="<?= $hoje ?>" class="<?= classe_erro($erros, 'previsao_liberacao') ?>">
                <small class="campo-ajuda">Se passar desta data, o sistema avisa nos alertas.</small>
                <?= erro_campo($erros, 'previsao_liberacao') ?>
            </div>
        </div>

        <div class="form-actions">
            <button type="submit" class="btn-primary" <?= !$veiculos ? 'disabled' : '' ?>>Enviar para manutenção</button>
            <a href="<?= e(url('manutencoes/index.php')) ?>" class="btn-secondary">Cancelar</a>
        </div>
    </form>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
