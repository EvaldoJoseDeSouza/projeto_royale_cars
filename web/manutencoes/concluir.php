<?php
/*
| CONCLUIR MANUTENÇÃO 
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/manutencoes.php';

exigir_permissao('manutencoes');

$id = (int) ($_GET['id'] ?? $_POST['id'] ?? 0);
$m = buscar_manutencao($id);

if (!$m || $m['status'] !== 'Em andamento') {
    flash('erro', 'Manutenção não encontrada ou já concluída.');
    redirecionar('manutencoes/index.php');
}

$hoje = date('Y-m-d');
$erros = [];

$dados = [
    'data_liberacao'    => (string) ($_POST['data_liberacao'] ?? $hoje),
    'servico_realizado' => trim((string) ($_POST['servico_realizado'] ?? '')),
    'custo'             => (string) ($_POST['custo'] ?? ''),
];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verificar_csrf();

    if (!validar_data($dados['data_liberacao'])) {
        $erros['data_liberacao'] = 'Informe a data de liberação.';
    }

    if (mb_strlen($dados['servico_realizado']) < 5 || mb_strlen($dados['servico_realizado']) > 1000) {
        $erros['servico_realizado'] = 'Descreva o serviço realizado.';
    }

    $custo = ler_dinheiro($dados['custo']);

    if ($custo === null || $custo < 0 || $custo > 1000000) {
        $erros['custo'] = 'Informe o custo do reparo (use 0 se foi na garantia).';
    }

    if (!$erros) {
        [, $erros] = chamar_funcao_manutencao('concluir_manutencao', [
            'p_manutencao_id'  => $id,
            'p_data_liberacao' => $dados['data_liberacao'],
            'p_servico'        => $dados['servico_realizado'],
            'p_custo'          => $custo,
        ]);

        if (!$erros) {
            flash('sucesso', nome_veiculo($m) . ' liberado da manutenção.');
            redirecionar('manutencoes/index.php?aba=concluidas');
        }
    }
}

$titulo = 'Liberar veículo';
$subtitulo = nome_veiculo($m) . ' · ' . formatar_placa($m['placa']);
$menu = 'manutencoes';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="form-container">
    <div class="page-header">
        <div>
            <h2>Concluir manutenção</h2>
            <p>Entrou na oficina em <strong><?= data_br($m['data_entrada']) ?></strong>: <?= e($m['defeito']) ?></p>
            <?php if ($vistoria = resumo_checklist($m)): ?>
                <p class="texto-fraco">Vistoria na entrada: <?= e($vistoria) ?><?= itens_com_problema($m) ? ' — problema em ' . e(itens_com_problema($m)) : '' ?></p>
            <?php endif; ?>
        </div>
        <a href="<?= e(url('manutencoes/index.php')) ?>" class="btn-secondary">Voltar</a>
    </div>

    <?= $erros ? mostrar_erros(array_unique(array_values($erros))) : '' ?>

    <form method="POST" novalidate>
        <?= csrf_campo() ?>
        <input type="hidden" name="id" value="<?= $id ?>">

        <div class="form-grid">
            <div class="form-group inteiro">
                <label for="servico_realizado">Serviço realizado *</label>
                <textarea id="servico_realizado" name="servico_realizado" maxlength="1000"
                          class="<?= classe_erro($erros, 'servico_realizado') ?>" required
                          placeholder="Ex.: troca dos amortecedores dianteiros"><?= e($dados['servico_realizado']) ?></textarea>
                <?= erro_campo($erros, 'servico_realizado') ?>
            </div>

            <div class="form-group">
                <label for="custo">Custo do reparo (R$) *</label>
                <input type="number" id="custo" name="custo" min="0" step="0.01" value="<?= e($dados['custo']) ?>"
                       class="<?= classe_erro($erros, 'custo') ?>" placeholder="Ex.: 850.00" required>
                <?= erro_campo($erros, 'custo') ?>
            </div>

            <div class="form-group">
                <label for="data_liberacao">Data de liberação *</label>
                <input type="date" id="data_liberacao" name="data_liberacao" value="<?= e($dados['data_liberacao']) ?>"
                       min="<?= e($m['data_entrada']) ?>" max="<?= $hoje ?>"
                       class="<?= classe_erro($erros, 'data_liberacao') ?>" required>
                <?= erro_campo($erros, 'data_liberacao') ?>
            </div>
        </div>

        <div class="form-actions">
            <button type="submit" class="btn-primary">Liberar veículo</button>
            <a href="<?= e(url('manutencoes/index.php')) ?>" class="btn-secondary">Cancelar</a>
        </div>
    </form>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
