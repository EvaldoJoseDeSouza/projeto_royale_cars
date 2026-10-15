<?php
/*
| Campos do formulário de cliente (usado em cadastrar e editar).
| Espera as variáveis $dados e $erros.
*/
?>
<div class="form-grid">

    <div class="form-group inteiro">
        <label for="nome">Nome completo *</label>
        <input type="text" id="nome" name="nome" value="<?= campo($dados, 'nome') ?>"
               placeholder="Ex.: Maria Aparecida Santos" maxlength="150"
               data-validar="nome" class="<?= classe_erro($erros, 'nome') ?>" required>
        <?= erro_campo($erros, 'nome') ?>
    </div>

    <div class="form-group">
        <label for="cpf">CPF *</label>
        <input type="text" id="cpf" name="cpf" value="<?= e(formatar_cpf($dados['cpf'] ?? '')) ?>"
               placeholder="000.000.000-00" inputmode="numeric" maxlength="14"
               data-mascara="cpf" data-validar="cpf" class="<?= classe_erro($erros, 'cpf') ?>" required>
        <?= erro_campo($erros, 'cpf') ?>
    </div>

    <div class="form-group">
        <label for="telefone">Telefone com DDD *</label>
        <input type="text" id="telefone" name="telefone" value="<?= e(formatar_telefone($dados['telefone'] ?? '')) ?>"
               placeholder="(19) 99999-9999" inputmode="numeric" maxlength="15"
               data-mascara="telefone" data-validar="telefone" class="<?= classe_erro($erros, 'telefone') ?>" required>
        <?= erro_campo($erros, 'telefone') ?>
    </div>

    <div class="form-group">
        <label for="cnh">Número da CNH *</label>
        <input type="text" id="cnh" name="cnh" value="<?= campo($dados, 'cnh') ?>"
               placeholder="11 números" inputmode="numeric" maxlength="11"
               data-mascara="cnh" data-validar="cnh" class="<?= classe_erro($erros, 'cnh') ?>" required>
        <small class="campo-ajuda">Número de registro que aparece na CNH.</small>
        <?= erro_campo($erros, 'cnh') ?>
    </div>

    <div class="form-group">
        <label for="cnh_validade">Validade da CNH *</label>
        <input type="date" id="cnh_validade" name="cnh_validade" value="<?= campo($dados, 'cnh_validade') ?>"
               class="<?= classe_erro($erros, 'cnh_validade') ?>" required>
        <small class="campo-ajuda">Cliente com CNH vencida não pode alugar.</small>
        <?= erro_campo($erros, 'cnh_validade') ?>
    </div>

    <div class="form-group inteiro">
        <label for="email">E-mail *</label>
        <input type="email" id="email" name="email" value="<?= campo($dados, 'email') ?>"
               placeholder="cliente@email.com" maxlength="150"
               data-validar="email" class="<?= classe_erro($erros, 'email') ?>" required>
        <?= erro_campo($erros, 'email') ?>
    </div>

    <div class="form-group inteiro">
        <label for="endereco">Endereço (opcional)</label>
        <input type="text" id="endereco" name="endereco" value="<?= campo($dados, 'endereco') ?>"
               placeholder="Rua, número - bairro, cidade/UF" maxlength="200"
               class="<?= classe_erro($erros, 'endereco') ?>">
        <?= erro_campo($erros, 'endereco') ?>
    </div>

</div>
