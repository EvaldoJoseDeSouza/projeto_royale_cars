<?php
/*
|--------------------------------------------------------------------------
| ENVIAR VEÍCULO PARA MANUTENÇÃO
|--------------------------------------------------------------------------
| Quem grava é a função abrir_manutencao do banco (a mesma do desktop e do
| celular): confere se o carro está Disponível, trava-o, registra a ida à
| oficina e marca o carro "Em manutenção" — tudo de uma vez.
| (Carro alugado vai para a manutenção na DEVOLUÇÃO, marcando
| "voltou com defeito".)
|
| Vistoria (opcional): o mesmo checklist do celular (motor, freios, pneus,
| óleo). Se a caixa "Fiz a vistoria" não for marcada, vai vazio (null).
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/manutencoes.php';

exigir_permissao('manutencoes');

$hoje = date('Y-m-d');
$erros = [];

$dados = [
    'veiculo_id'         => (int) ($_POST['veiculo_id'] ?? $_GET['veiculo_id'] ?? 0),
    'defeito'            => trim((string) ($_POST['defeito'] ?? '')),
    'oficina'            => trim((string) ($_POST['oficina'] ?? '')),
    'data_entrada'       => (string) ($_POST['data_entrada'] ?? $hoje),
    'previsao_liberacao' => (string) ($_POST['previsao_liberacao'] ?? ''),
    'fez_vistoria'       => !empty($_POST['fez_vistoria']),
];

foreach (array_keys(CHECKLIST_MANUTENCAO) as $item) {
    $dados[$item] = !empty($_POST[$item]);
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verificar_csrf();

    if ($dados['veiculo_id'] <= 0) {
        $erros['veiculo_id'] = 'Selecione o veículo.';
    }

    if (mb_strlen($dados['defeito']) < 5 || mb_strlen($dados['defeito']) > 1000) {
        $erros['defeito'] = 'Descreva o defeito ou o serviço (mínimo 5 caracteres).';
    }

    if (!validar_data($dados['data_entrada'])) {
        $erros['data_entrada'] = 'Informe a data de entrada na oficina.';
    }

    if ($dados['previsao_liberacao'] !== '' && !validar_data($dados['previsao_liberacao'])) {
        $erros['previsao_liberacao'] = 'Data de previsão inválida.';
    }

    if (!$erros) {
        $parametros = [
            'p_veiculo_id'   => $dados['veiculo_id'],
            'p_defeito'      => $dados['defeito'],
            'p_oficina'      => $dados['oficina'] !== '' ? $dados['oficina'] : null,
            'p_data_entrada' => $dados['data_entrada'],
            'p_previsao'     => $dados['previsao_liberacao'] !== '' ? $dados['previsao_liberacao'] : null,
        ];

        // Cada item: marcado = OK (true), desmarcado = com problema (false).
        // Sem vistoria, os 4 ficam null ("não foi verificado").
        foreach (array_keys(CHECKLIST_MANUTENCAO) as $item) {
            $parametros['p_' . $item] = $dados['fez_vistoria'] ? $dados[$item] : null;
        }

        [$id, $erros] = chamar_funcao_manutencao('abrir_manutencao', $parametros);

        if ($id) {
            flash('sucesso', 'Veículo enviado para manutenção. Ele não poderá ser alugado até ser liberado.');
            redirecionar('manutencoes/index.php');
        }
    }
}

$veiculos = sb_select('veiculos', [
    'select'    => 'id,marca,modelo,placa',
    'arquivado' => 'eq.false',
    'status'    => 'eq.Disponível',
    'order'     => 'marca.asc,modelo.asc',
]);

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

        <h3 class="secao-form">Vistoria (opcional)</h3>

        <label class="checkbox">
            <input type="checkbox" id="fez_vistoria" name="fez_vistoria" value="1" <?= $dados['fez_vistoria'] ? 'checked' : '' ?>>
            Fiz a vistoria do veículo (o mesmo checklist do celular)
        </label>

        <div id="area-vistoria" class="checklist" <?= $dados['fez_vistoria'] ? '' : 'hidden' ?>>
            <p class="campo-ajuda">Marque o que está OK. O que ficar desmarcado é registrado como problema.</p>
            <?php foreach (CHECKLIST_MANUTENCAO as $item => $nome): ?>
                <label class="checkbox">
                    <input type="checkbox" name="<?= $item ?>" value="1" <?= $dados[$item] ? 'checked' : '' ?>> <?= e($nome) ?> OK
                </label>
            <?php endforeach; ?>
        </div>

        <div class="form-actions">
            <button type="submit" class="btn-primary" <?= !$veiculos ? 'disabled' : '' ?>>Enviar para manutenção</button>
            <a href="<?= e(url('manutencoes/index.php')) ?>" class="btn-secondary">Cancelar</a>
        </div>
    </form>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
