<?php
/*
|--------------------------------------------------------------------------
| NOVO ALUGUEL (registrar retirada)
|--------------------------------------------------------------------------
| Regras:
|  - Só clientes ativos, com CNH válida até o fim do aluguel.
|  - Só veículos "Disponível" (não alugados e sem manutenção pendente).
|  - Tudo é gravado numa transação, com o veículo "travado" (FOR UPDATE):
|    se duas pessoas tentarem alugar o mesmo carro ao mesmo tempo, só a
|    primeira consegue.
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/locacoes.php';

exigir_permissao('locacoes_gerenciar');

$hoje = date('Y-m-d');
$erros = [];

$dados = [
    'cliente_id'    => (int) ($_POST['cliente_id'] ?? $_GET['cliente_id'] ?? 0),
    'veiculo_id'    => (int) ($_POST['veiculo_id'] ?? $_GET['veiculo_id'] ?? 0),
    'data_retirada' => (string) ($_POST['data_retirada'] ?? $hoje),
    'data_prevista' => (string) ($_POST['data_prevista'] ?? date('Y-m-d', strtotime('+3 days'))),
    'observacoes'   => trim((string) ($_POST['observacoes'] ?? '')),
];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verificar_csrf();

    $cliente = db_linha('SELECT * FROM clientes WHERE id = ? AND arquivado = 0', [$dados['cliente_id']]);

    if (!$cliente) {
        $erros['cliente_id'] = 'Selecione um cliente ativo.';
    }

    if ($dados['veiculo_id'] <= 0) {
        $erros['veiculo_id'] = 'Selecione um veículo disponível.';
    }

    if (!validar_data($dados['data_retirada'])) {
        $erros['data_retirada'] = 'Informe a data de retirada.';
    } elseif ($dados['data_retirada'] > $hoje) {
        $erros['data_retirada'] = 'A retirada não pode ser no futuro. Registre o aluguel no dia em que o cliente pegar o carro.';
    } elseif ($dados['data_retirada'] < date('Y-m-d', strtotime('-' . MAX_DIAS_RETROATIVO . ' days'))) {
        $erros['data_retirada'] = 'A retirada não pode ser de mais de ' . MAX_DIAS_RETROATIVO . ' dias atrás.';
    }

    if (!validar_data($dados['data_prevista'])) {
        $erros['data_prevista'] = 'Informe a data prevista de devolução.';
    } elseif (!isset($erros['data_retirada'])) {
        if ($dados['data_prevista'] < $dados['data_retirada']) {
            $erros['data_prevista'] = 'A devolução não pode ser antes da retirada.';
        } elseif (dias_entre($dados['data_retirada'], $dados['data_prevista']) > MAX_DIAS_LOCACAO) {
            $erros['data_prevista'] = 'O aluguel pode ter no máximo ' . MAX_DIAS_LOCACAO . ' dias.';
        } elseif ($dados['data_prevista'] < $hoje) {
            $erros['data_prevista'] = 'A devolução prevista não pode ser antes de hoje.';
        }
    }

    if ($cliente && !isset($erros['data_prevista'])) {
        if ($cliente['cnh_validade'] < $hoje) {
            $erros['cliente_id'] = "A CNH de {$cliente['nome']} venceu em " . data_br($cliente['cnh_validade']) . '. Atualize o cadastro antes de alugar.';
        } elseif ($cliente['cnh_validade'] < $dados['data_prevista']) {
            $erros['cliente_id'] = "A CNH de {$cliente['nome']} vence em " . data_br($cliente['cnh_validade']) . ', antes do fim do aluguel.';
        }
    }

    if (mb_strlen($dados['observacoes']) > 1000) {
        $erros['observacoes'] = 'Observações com no máximo 1000 caracteres.';
    }

    if (!$erros) {
        try {
            $id = em_transacao(function () use ($dados, $cliente) {
                // Trava a linha do veículo até o fim da transação
                $veiculo = db_linha('SELECT * FROM veiculos WHERE id = ? FOR UPDATE', [$dados['veiculo_id']]);

                if (!$veiculo || $veiculo['arquivado']) {
                    throw new RegraNegocio('Veículo não encontrado.');
                }

                if ($veiculo['status'] !== 'Disponível') {
                    throw new RegraNegocio(nome_veiculo($veiculo) . ' não está disponível (status: ' . $veiculo['status'] . ').');
                }

                $manutencaoAberta = db_valor(
                    "SELECT COUNT(*) FROM manutencoes WHERE veiculo_id = ? AND status = 'Em andamento'",
                    [$veiculo['id']]
                );

                if ($manutencaoAberta) {
                    throw new RegraNegocio(nome_veiculo($veiculo) . ' tem manutenção pendente e não pode ser alugado.');
                }

                $previsto = calcular_previsto($dados['data_retirada'], $dados['data_prevista'], (float) $veiculo['valor_diaria']);

                db_executar(
                    "INSERT INTO locacoes
                        (cliente_id, veiculo_id, usuario_id, data_retirada, data_prevista,
                         valor_diaria, dias_previstos, valor_previsto, valor_total, status, observacoes)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'Em andamento', ?)",
                    [
                        $cliente['id'], $veiculo['id'], (int) $_SESSION['usuario_id'],
                        $dados['data_retirada'], $dados['data_prevista'],
                        (float) $veiculo['valor_diaria'], $previsto['dias'], $previsto['valor'], $previsto['valor'],
                        $dados['observacoes'] !== '' ? $dados['observacoes'] : null,
                    ]
                );

                $id = db_ultimo_id();

                db_executar("UPDATE veiculos SET status = 'Alugado' WHERE id = ?", [$veiculo['id']]);

                registrar_log('locacoes', 'cadastrar', $id,
                    "Registrou o aluguel #{$id}: " . nome_veiculo($veiculo) . ' (' . formatar_placa($veiculo['placa']) . ") para {$cliente['nome']}, "
                    . data_br($dados['data_retirada']) . ' a ' . data_br($dados['data_prevista'])
                    . ", {$previsto['dias']} diária(s), previsto " . moeda($previsto['valor']) . '.');

                return $id;
            });

            flash('sucesso', "Aluguel #{$id} registrado. O veículo agora está como Alugado.");
            redirecionar('locacoes/ver.php?id=' . $id);
        } catch (RegraNegocio $e) {
            $erros['veiculo_id'] = $e->getMessage();
        }
    }
}

$clientes = db_todos('SELECT id, nome, cpf, cnh_validade FROM clientes WHERE arquivado = 0 ORDER BY nome');

$veiculos = db_todos(
    "SELECT id, marca, modelo, placa, ano, valor_diaria
     FROM veiculos
     WHERE arquivado = 0 AND status = 'Disponível'
     ORDER BY marca, modelo"
);

$titulo = 'Novo aluguel';
$subtitulo = 'Registrar a retirada de um veículo';
$menu = 'locacoes';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="form-container">
    <div class="page-header">
        <div>
            <h2>Registrar retirada</h2>
            <p>O valor é calculado automaticamente pela diária do veículo.</p>
        </div>
        <a href="<?= e(url('locacoes/index.php')) ?>" class="btn-secondary">Voltar</a>
    </div>

    <?= $erros ? mostrar_erros(array_unique(array_values($erros))) : '' ?>

    <?php if (!$veiculos): ?>
        <div class="alert-warning">Nenhum veículo disponível no momento.</div>
    <?php endif; ?>

    <form method="POST" data-calculo-locacao novalidate>
        <?= csrf_campo() ?>

        <div class="form-grid">
            <div class="form-group">
                <label for="cliente_id">Cliente *</label>
                <select id="cliente_id" name="cliente_id" class="<?= classe_erro($erros, 'cliente_id') ?>" required>
                    <option value="">Selecione um cliente</option>
                    <?php foreach ($clientes as $c): ?>
                        <?php $vencida = $c['cnh_validade'] < $hoje; ?>
                        <option value="<?= $c['id'] ?>" <?= $dados['cliente_id'] === (int) $c['id'] ? 'selected' : '' ?> <?= $vencida ? 'disabled' : '' ?>>
                            <?= e($c['nome']) ?> — <?= e(formatar_cpf($c['cpf'])) ?><?= $vencida ? ' (CNH vencida)' : '' ?>
                        </option>
                    <?php endforeach; ?>
                </select>
                <?= erro_campo($erros, 'cliente_id') ?>
            </div>

            <div class="form-group">
                <label for="veiculo_id">Veículo disponível *</label>
                <select id="veiculo_id" name="veiculo_id" class="<?= classe_erro($erros, 'veiculo_id') ?>" required>
                    <option value="" data-diaria="0">Selecione um veículo</option>
                    <?php foreach ($veiculos as $v): ?>
                        <option value="<?= $v['id'] ?>" data-diaria="<?= e($v['valor_diaria']) ?>" <?= $dados['veiculo_id'] === (int) $v['id'] ? 'selected' : '' ?>>
                            <?= e(nome_veiculo($v)) ?> <?= (int) $v['ano'] ?> — <?= e(formatar_placa($v['placa'])) ?> — <?= moeda($v['valor_diaria']) ?>/dia
                        </option>
                    <?php endforeach; ?>
                </select>
                <?= erro_campo($erros, 'veiculo_id') ?>
            </div>

            <div class="form-group">
                <label for="data_retirada">Data da retirada *</label>
                <input type="date" id="data_retirada" name="data_retirada" value="<?= e($dados['data_retirada']) ?>"
                       max="<?= $hoje ?>" min="<?= date('Y-m-d', strtotime('-' . MAX_DIAS_RETROATIVO . ' days')) ?>"
                       class="<?= classe_erro($erros, 'data_retirada') ?>" required>
                <?= erro_campo($erros, 'data_retirada') ?>
            </div>

            <div class="form-group">
                <label for="data_prevista">Devolução prevista *</label>
                <input type="date" id="data_prevista" name="data_prevista" value="<?= e($dados['data_prevista']) ?>"
                       min="<?= $hoje ?>" class="<?= classe_erro($erros, 'data_prevista') ?>" required>
                <?= erro_campo($erros, 'data_prevista') ?>
            </div>

            <div class="form-group inteiro">
                <label for="observacoes">Observações</label>
                <textarea id="observacoes" name="observacoes" maxlength="1000"
                          placeholder="Ex.: tanque cheio, quilometragem, avarias já existentes..."><?= e($dados['observacoes']) ?></textarea>
            </div>
        </div>

        <div class="resumo-calculo">
            <div><span>Diária</span><strong id="prev-diaria">—</strong></div>
            <div><span>Período</span><strong id="prev-dias">—</strong></div>
            <div><span>Valor previsto</span><strong id="prev-total">—</strong></div>
        </div>

        <div class="form-actions">
            <button type="submit" class="btn-primary" <?= !$veiculos ? 'disabled' : '' ?>>Registrar aluguel</button>
            <a href="<?= e(url('locacoes/index.php')) ?>" class="btn-secondary">Cancelar</a>
        </div>
    </form>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
