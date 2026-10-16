<?php
/*
|--------------------------------------------------------------------------
| NOVO ALUGUEL (registrar retirada)
|--------------------------------------------------------------------------
| Quem decide se pode alugar é a função registrar_aluguel do banco (a
| mesma do desktop e do celular). Ela confere, numa transação só:
|  - cliente ativo, com CNH válida até o fim do aluguel;
|  - veículo "Disponível" (e o "trava": se duas pessoas tentarem alugar o
|    mesmo carro ao mesmo tempo, só a primeira consegue);
|  - datas (retirada de até 30 dias atrás, no máximo 365 dias);
|  - quilometragem de saída não menor que a atual do carro.
| Se algo não passar, ela responde com a frase pronta, que mostramos ao
| lado do campo certo. Aqui só conferimos o básico (campos preenchidos).
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
    'km_saida'      => so_digitos($_POST['km_saida'] ?? ''),
    'observacoes'   => trim((string) ($_POST['observacoes'] ?? '')),
];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verificar_csrf();

    if ($dados['cliente_id'] <= 0) {
        $erros['cliente_id'] = 'Selecione um cliente ativo.';
    }

    if ($dados['veiculo_id'] <= 0) {
        $erros['veiculo_id'] = 'Selecione um veículo disponível.';
    }

    if (!validar_data($dados['data_retirada'])) {
        $erros['data_retirada'] = 'Informe a data de retirada.';
    }

    if (!validar_data($dados['data_prevista'])) {
        $erros['data_prevista'] = 'Informe a data prevista de devolução.';
    }

    if (mb_strlen($dados['observacoes']) > 1000) {
        $erros['observacoes'] = 'Observações com no máximo 1000 caracteres.';
    }

    if (!$erros) {
        [$id, $erros] = chamar_funcao_locacao('registrar_aluguel', [
            'p_cliente_id'    => $dados['cliente_id'],
            'p_veiculo_id'    => $dados['veiculo_id'],
            'p_data_retirada' => $dados['data_retirada'],
            'p_data_prevista' => $dados['data_prevista'],
            'p_observacoes'   => $dados['observacoes'] !== '' ? $dados['observacoes'] : null,
            // Vazio = o banco usa a quilometragem atual do carro
            'p_km_saida'      => $dados['km_saida'] !== '' ? (int) $dados['km_saida'] : null,
        ]);

        // Nesta tela, "devolução" só pode ser a prevista
        if (isset($erros['data_devolucao'])) {
            $erros['data_prevista'] = $erros['data_devolucao'];
            unset($erros['data_devolucao']);
        }

        if ($id) {
            flash('sucesso', "Aluguel #{$id} registrado. O veículo agora está como Alugado.");
            redirecionar('locacoes/ver.php?id=' . $id);
        }
    }
}

// Listas dos campos de escolha
$clientes = sb_select('clientes', [
    'select'    => 'id,nome,cpf,cnh_validade',
    'arquivado' => 'eq.false',
    'order'     => 'nome.asc',
]);

$veiculos = sb_select('veiculos', [
    'select'    => 'id,marca,modelo,placa,ano,valor_diaria,quilometragem',
    'arquivado' => 'eq.false',
    'status'    => 'eq.Disponível',
    'order'     => 'marca.asc,modelo.asc',
]);

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
                        <option value="<?= $v['id'] ?>" data-diaria="<?= e($v['valor_diaria']) ?>" data-km="<?= (int) $v['quilometragem'] ?>"
                                <?= $dados['veiculo_id'] === (int) $v['id'] ? 'selected' : '' ?>>
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

            <div class="form-group">
                <label for="km_saida">Quilometragem de saída (km) *</label>
                <input type="number" id="km_saida" name="km_saida" value="<?= e($dados['km_saida']) ?>"
                       min="0" step="1" class="<?= classe_erro($erros, 'km_saida') ?>" required>
                <small class="campo-ajuda" id="km-ajuda">Vem preenchida com a do veículo. Não pode ser menor.</small>
                <?= erro_campo($erros, 'km_saida') ?>
            </div>

            <div class="form-group inteiro">
                <label for="observacoes">Observações</label>
                <textarea id="observacoes" name="observacoes" maxlength="1000"
                          placeholder="Ex.: tanque cheio, avarias já existentes..."><?= e($dados['observacoes']) ?></textarea>
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
