<?php
/*
|--------------------------------------------------------------------------
| REGISTRAR DEVOLUÇÃO
|--------------------------------------------------------------------------
| Quem calcula e grava é a função registrar_devolucao do banco (a mesma do
| desktop e do celular), numa transação só:
|  - dias usados × diária (mínimo 1), com o atraso já somado;
|  - taxas extras com motivo (combustível, limpeza, avaria);
|  - quilometragem de retorno (atualiza a do carro);
|  - libera o carro, ou manda direto para a oficina se voltou com defeito.
| Ela devolve um resumo (dias, atraso, taxas, km rodados, total), que
| mostramos na tela como comprovante.
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/locacoes.php';

exigir_permissao('locacoes_gerenciar');

$id = (int) ($_GET['id'] ?? $_POST['id'] ?? 0);

$l = $id > 0 ? sb_linha('vw_locacoes', [
    'select' => 'id,status,cliente_nome,marca,modelo,placa,data_retirada,data_prevista,valor_diaria,km_saida',
    'id'     => 'eq.' . $id,
]) : null;

if (!$l || $l['status'] !== 'Em andamento') {
    flash('erro', 'Aluguel não encontrado ou já encerrado.');
    redirecionar('locacoes/index.php');
}

$hoje = date('Y-m-d');
$erros = [];

$dados = [
    'data_devolucao'    => (string) ($_POST['data_devolucao'] ?? max($hoje, $l['data_retirada'])),
    'km_retorno'        => so_digitos($_POST['km_retorno'] ?? ''),
    'taxas_extras'      => (string) ($_POST['taxas_extras'] ?? ''),
    'taxas_motivo'      => trim((string) ($_POST['taxas_motivo'] ?? '')),
    'observacoes'       => trim((string) ($_POST['observacoes'] ?? '')),
    'enviar_manutencao' => !empty($_POST['enviar_manutencao']),
    'defeito'           => trim((string) ($_POST['defeito'] ?? '')),
    'oficina'           => trim((string) ($_POST['oficina'] ?? '')),
];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verificar_csrf();

    if (!validar_data($dados['data_devolucao'])) {
        $erros['data_devolucao'] = 'Informe a data da devolução.';
    }

    if ($dados['km_retorno'] === '') {
        $erros['km_retorno'] = 'Informe a quilometragem de retorno.';
    }

    $taxas = $dados['taxas_extras'] === '' ? 0.0 : ler_dinheiro($dados['taxas_extras']);

    if ($taxas === null || $taxas < 0) {
        $erros['taxas_extras'] = 'Valor das taxas extras inválido.';
    }

    if ($dados['enviar_manutencao'] && mb_strlen($dados['defeito']) < 5) {
        $erros['defeito'] = 'Descreva o defeito encontrado.';
    }

    if (mb_strlen($dados['observacoes']) > 1000 || mb_strlen($dados['defeito']) > 1000
        || mb_strlen($dados['oficina']) > 150 || mb_strlen($dados['taxas_motivo']) > 200) {
        $erros['geral'] = 'Texto muito longo em algum campo.';
    }

    if (!$erros) {
        [$resumo, $erros] = chamar_funcao_locacao('registrar_devolucao', [
            'p_locacao_id'     => $id,
            'p_data_devolucao' => $dados['data_devolucao'],
            'p_observacoes'    => $dados['observacoes'] !== '' ? $dados['observacoes'] : null,
            // Só manda o defeito se a caixinha estiver marcada
            'p_defeito'        => $dados['enviar_manutencao'] ? $dados['defeito'] : null,
            'p_oficina'        => $dados['enviar_manutencao'] && $dados['oficina'] !== '' ? $dados['oficina'] : null,
            'p_km_retorno'     => (int) $dados['km_retorno'],
            'p_taxas_extras'   => $taxas,
            'p_taxas_motivo'   => $dados['taxas_motivo'] !== '' ? $dados['taxas_motivo'] : null,
        ]);

        if ($resumo) {
            // O comprovante, com os números que o BANCO calculou
            $partes = [$resumo['dias'] . ' diária(s): ' . moeda($resumo['valor_diarias'])];

            if ($resumo['dias_atraso'] > 0) {
                $partes[] = $resumo['dias_atraso'] . ' dia(s) de atraso (já somados)';
            }

            if ($resumo['taxas_extras'] > 0) {
                $partes[] = 'taxas extras: ' . moeda($resumo['taxas_extras']);
            }

            if ($resumo['km_rodados'] !== null) {
                $partes[] = 'rodou ' . number_format((int) $resumo['km_rodados'], 0, ',', '.') . ' km';
            }

            flash('sucesso', 'Devolução registrada. ' . implode('; ', $partes)
                . '. Total: ' . moeda($resumo['valor_total']) . '. Veículo agora: ' . $resumo['status_veiculo'] . '.');
            redirecionar('locacoes/ver.php?id=' . $id);
        }
    }
}

$titulo = 'Registrar devolução';
$subtitulo = 'Aluguel #' . $l['id'] . ' · ' . nome_veiculo($l) . ' · ' . $l['cliente_nome'];
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
                <?php if ($l['km_saida'] !== null): ?>
                    Saiu com <strong><?= number_format((int) $l['km_saida'], 0, ',', '.') ?> km</strong>.
                <?php endif; ?>
            </p>
        </div>
        <a href="<?= e(url('locacoes/ver.php?id=' . $id)) ?>" class="btn-secondary">Voltar</a>
    </div>

    <?= $erros ? mostrar_erros(array_unique(array_values($erros))) : '' ?>

    <form method="POST" novalidate data-calculo-devolucao
          data-diaria="<?= e($l['valor_diaria']) ?>"
          data-retirada="<?= e($l['data_retirada']) ?>"
          data-prevista="<?= e($l['data_prevista']) ?>"
          data-km-saida="<?= (int) $l['km_saida'] ?>"
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
                <label for="km_retorno">Quilometragem de retorno (km) *</label>
                <input type="number" id="km_retorno" name="km_retorno" value="<?= e($dados['km_retorno']) ?>"
                       min="<?= (int) $l['km_saida'] ?>" step="1" class="<?= classe_erro($erros, 'km_retorno') ?>" required>
                <small class="campo-ajuda">Não pode ser menor que a de saída.</small>
                <?= erro_campo($erros, 'km_retorno') ?>
            </div>

            <div class="form-group">
                <label for="taxas_extras">Taxas extras (R$)</label>
                <input type="number" id="taxas_extras" name="taxas_extras" value="<?= e($dados['taxas_extras']) ?>"
                       min="0" step="0.01" placeholder="0,00" class="<?= classe_erro($erros, 'taxas_extras') ?>">
                <?= erro_campo($erros, 'taxas_extras') ?>
            </div>

            <div class="form-group">
                <label for="taxas_motivo">Motivo das taxas</label>
                <input type="text" id="taxas_motivo" name="taxas_motivo" value="<?= e($dados['taxas_motivo']) ?>"
                       maxlength="200" placeholder="Ex.: combustível, limpeza, avaria">
                <small class="campo-ajuda">Obrigatório se houver taxa.</small>
            </div>

            <div class="form-group inteiro">
                <label for="observacoes">Observações da devolução</label>
                <input type="text" id="observacoes" name="observacoes" value="<?= e($dados['observacoes']) ?>"
                       maxlength="1000" placeholder="Ex.: tanque cheio, sem avarias">
            </div>
        </div>

        <div class="resumo-calculo">
            <div><span>Diárias cobradas</span><strong id="dev-dias">—</strong></div>
            <div><span>Atraso</span><strong id="dev-atraso">—</strong></div>
            <div><span>Taxas extras</span><strong id="dev-taxas">—</strong></div>
            <div><span>Rodou</span><strong id="dev-km">—</strong></div>
            <div><span>Total a cobrar</span><strong id="dev-total">—</strong></div>
        </div>
        <p class="campo-ajuda">Prévia. O valor final é calculado pelo banco ao confirmar.</p>

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
