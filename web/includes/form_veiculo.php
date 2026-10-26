<?php
/*
| Campos do formulário de veículo
*/

$alugado = isset($veiculo) && $veiculo['status'] === 'Alugado';

$valorDiaria = $dados['valor_diaria'] ?? '';

if (is_numeric($valorDiaria)) {
    $valorDiaria = number_format((float) $valorDiaria, 2, '.', '');
}
?>
<div class="form-grid form-grid-3">

    <div class="form-group">
        <label for="marca">Marca *</label>
        <input type="text" id="marca" name="marca" value="<?= campo($dados, 'marca') ?>"
               placeholder="Ex.: Toyota" maxlength="100" class="<?= classe_erro($erros, 'marca') ?>" required>
        <?= erro_campo($erros, 'marca') ?>
    </div>

    <div class="form-group">
        <label for="modelo">Modelo *</label>
        <input type="text" id="modelo" name="modelo" value="<?= campo($dados, 'modelo') ?>"
               placeholder="Ex.: Corolla XEi" maxlength="100" class="<?= classe_erro($erros, 'modelo') ?>" required>
        <?= erro_campo($erros, 'modelo') ?>
    </div>

    <div class="form-group">
        <label for="ano">Ano *</label>
        <input type="number" id="ano" name="ano" value="<?= campo($dados, 'ano') ?>"
               min="1950" max="<?= (int) date('Y') + 1 ?>" placeholder="Ex.: <?= date('Y') ?>"
               class="<?= classe_erro($erros, 'ano') ?>" required>
        <?= erro_campo($erros, 'ano') ?>
    </div>

    <div class="form-group">
        <label for="placa">Placa *</label>
        <input type="text" id="placa" name="placa" value="<?= e(formatar_placa($dados['placa'] ?? '')) ?>"
               placeholder="ABC-1234 ou ABC1D23" maxlength="8"
               data-mascara="placa" data-validar="placa" class="<?= classe_erro($erros, 'placa') ?>" required>
        <small class="campo-ajuda">Aceita placa antiga e Mercosul.</small>
        <?= erro_campo($erros, 'placa') ?>
    </div>

    <div class="form-group">
        <label for="chassi">Chassi *</label>
        <input type="text" id="chassi" name="chassi" value="<?= campo($dados, 'chassi') ?>"
               placeholder="17 caracteres" maxlength="17"
               data-mascara="chassi" data-validar="chassi" class="<?= classe_erro($erros, 'chassi') ?>" required>
        <small class="campo-ajuda">17 letras/números. Não existe I, O nem Q em chassi.</small>
        <?= erro_campo($erros, 'chassi') ?>
    </div>

    <div class="form-group">
        <label for="valor_diaria">Valor da diária (R$) *</label>
        <input type="number" id="valor_diaria" name="valor_diaria" value="<?= e($valorDiaria) ?>"
               min="1" max="100000" step="0.01" placeholder="Ex.: 250.00"
               class="<?= classe_erro($erros, 'valor_diaria') ?>" required>
        <?= erro_campo($erros, 'valor_diaria') ?>
    </div>

    <div class="form-group">
        <label for="quilometragem">Quilometragem atual (km) *</label>
        <input type="number" id="quilometragem" name="quilometragem" value="<?= campo($dados, 'quilometragem') ?>"
               min="0" max="<?= KM_MAXIMO ?>" step="1" placeholder="Ex.: 15000"
               class="<?= classe_erro($erros, 'quilometragem') ?>" <?= $alugado ? 'disabled' : 'required' ?>>
        <small class="campo-ajuda">
            <?= $alugado ? 'O carro está alugado: a quilometragem é atualizada na devolução.' : 'Depois, ela muda sozinha a cada devolução.' ?>
        </small>
        <?= erro_campo($erros, 'quilometragem') ?>
    </div>

    <div class="form-group inteiro">
        <label for="imagem">Foto do veículo</label>
        <input type="file" id="imagem" name="imagem" accept="image/jpeg,image/png,image/webp"
               data-preview="preview-imagem" class="<?= classe_erro($erros, 'imagem') ?>">
        <small class="campo-ajuda">JPG, PNG ou WEBP de até 2 MB. Opcional.</small>
        <?= erro_campo($erros, 'imagem') ?>

        <?php if (!empty($dados['imagem'])): ?>
            <img src="<?= e(url_foto_veiculo($dados['imagem'])) ?>" id="preview-imagem" class="preview-imagem" alt="Foto atual">
            <label class="checkbox">
                <input type="checkbox" name="remover_imagem" value="1"> Remover a foto atual
            </label>
        <?php else: ?>
            <img id="preview-imagem" class="preview-imagem" alt="Prévia" hidden>
        <?php endif; ?>
    </div>

</div>
