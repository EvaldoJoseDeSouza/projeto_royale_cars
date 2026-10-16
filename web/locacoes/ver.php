<?php
/*
|--------------------------------------------------------------------------
| DETALHES DO ALUGUEL (também serve como comprovante para imprimir)
|--------------------------------------------------------------------------
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/locacoes.php';

exigir_permissao('locacoes_ver');

$id = (int) ($_GET['id'] ?? 0);
$l = buscar_locacao($id);

if (!$l) {
    flash('erro', 'Aluguel não encontrado.');
    redirecionar('locacoes/index.php');
}

$status = status_locacao($l);
$hoje = date('Y-m-d');

// Para aluguel em andamento, mostra quanto daria se devolvesse hoje
$seDevolverHoje = null;

if ($l['status'] === 'Em andamento') {
    $dias = max(1, dias_entre($l['data_retirada'], max($hoje, $l['data_retirada'])));
    $atraso = max(0, dias_entre($l['data_prevista'], $hoje));
    $seDevolverHoje = ['dias' => $dias, 'atraso' => $atraso, 'total' => $dias * $l['valor_diaria']];
}

$titulo = 'Aluguel #' . $l['id'];
$subtitulo = nome_veiculo($l) . ' para ' . $l['cliente'];
$menu = 'locacoes';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="so-impressao" style="margin-bottom: 16px;">
    <h2>ROYALE CARS — Comprovante de aluguel #<?= $l['id'] ?></h2>
    <p>Emitido em <?= date('d/m/Y H:i') ?></p>
</div>

<?php if ($status === 'Atrasada'): ?>
    <div class="alert-error nao-imprimir">
        Este aluguel está <strong><?= dias_entre($l['data_prevista'], $hoje) ?> dia(s) atrasado</strong>.
        A devolução era em <?= data_br($l['data_prevista']) ?>. Entre em contato: <?= e(formatar_telefone($l['telefone'])) ?>.
    </div>
<?php endif; ?>

<div class="page-header nao-imprimir">
    <div>
        <h2>Situação: <?= badge_status($status) ?></h2>
        <p>Registrado por <?= e($l['registrado_por'] ?? '—') ?> em <?= data_hora_br($l['criado_em']) ?>.</p>
    </div>

    <div class="acoes-topo">
        <a href="<?= e(url('locacoes/index.php')) ?>" class="btn-secondary">Voltar</a>
        <button type="button" class="btn-secondary" onclick="window.print()">Imprimir</button>

        <?php if ($l['status'] === 'Em andamento' && pode('locacoes_gerenciar')): ?>
            <a href="<?= e(url('locacoes/devolver.php?id=' . $id)) ?>" class="btn-primary">Registrar devolução</a>
        <?php endif; ?>
    </div>
</div>

<div class="grade-2">
    <div class="bloco">
        <h2>Cliente</h2>
        <div class="ficha" style="grid-template-columns: 1fr 1fr;">
            <div><span>Nome</span><strong><?= e($l['cliente']) ?></strong></div>
            <div><span>CPF</span><strong><?= e(formatar_cpf($l['cpf'])) ?></strong></div>
            <div><span>Telefone</span><strong><?= e(formatar_telefone($l['telefone'])) ?></strong></div>
            <div><span>E-mail</span><strong><?= e($l['email']) ?></strong></div>
            <div><span>CNH</span><strong><?= e($l['cnh']) ?></strong></div>
            <div><span>Validade CNH</span><strong><?= data_br($l['cnh_validade']) ?></strong></div>
        </div>
    </div>

    <div class="bloco">
        <h2>Veículo</h2>
        <div class="ficha" style="grid-template-columns: 1fr 1fr;">
            <div><span>Veículo</span><strong><?= e(nome_veiculo($l)) ?></strong></div>
            <div><span>Ano</span><strong><?= (int) $l['ano'] ?></strong></div>
            <div><span>Placa</span><strong><?= e(formatar_placa($l['placa'])) ?></strong></div>
            <div><span>Chassi</span><strong><?= e($l['chassi']) ?></strong></div>
            <div><span>Diária combinada</span><strong><?= moeda($l['valor_diaria']) ?></strong></div>
        </div>
    </div>
</div>

<div class="bloco">
    <h2>Período e valores</h2>

    <div class="ficha">
        <div><span>Retirada</span><strong><?= data_br($l['data_retirada']) ?></strong></div>
        <div><span>Devolução prevista</span><strong><?= data_br($l['data_prevista']) ?></strong></div>
        <div><span>Devolvido em</span><strong><?= data_br($l['data_devolucao']) ?></strong></div>
        <div><span>Diárias previstas</span><strong><?= (int) $l['dias_previstos'] ?></strong></div>
        <div><span>Km na saída</span><strong><?= $l['km_saida'] !== null ? number_format((int) $l['km_saida'], 0, ',', '.') . ' km' : '—' ?></strong></div>
        <?php if ($l['km_retorno'] !== null): ?>
            <div>
                <span>Km na volta</span>
                <strong><?= number_format((int) $l['km_retorno'], 0, ',', '.') ?> km</strong>
                <small class="texto-fraco">rodou <?= number_format((int) $l['km_retorno'] - (int) $l['km_saida'], 0, ',', '.') ?> km</small>
            </div>
        <?php endif; ?>
        <div><span>Valor previsto</span><strong><?= moeda($l['valor_previsto']) ?></strong></div>

        <?php if ($l['status'] === 'Finalizada'): ?>
            <div>
                <span>Atraso</span>
                <strong class="<?= $l['dias_atraso'] > 0 ? 'texto-vermelho' : '' ?>">
                    <?= $l['dias_atraso'] > 0 ? $l['dias_atraso'] . ' dia(s) — ' . moeda($l['valor_atraso']) : 'Sem atraso' ?>
                </strong>
            </div>
            <?php if ((float) $l['taxas_extras'] > 0): ?>
                <div>
                    <span>Taxas extras</span>
                    <strong><?= moeda($l['taxas_extras']) ?></strong>
                    <small class="texto-fraco"><?= e($l['taxas_motivo']) ?></small>
                </div>
            <?php endif; ?>
            <div><span>Total cobrado</span><strong style="font-size: 20px; color: var(--azul);"><?= moeda($l['valor_total']) ?></strong></div>
            <div><span>Devolução registrada por</span><strong><?= e($l['encerrado_por'] ?? '—') ?></strong></div>
        <?php elseif ($l['status'] === 'Cancelada'): ?>
            <div><span>Cancelado por</span><strong><?= e($l['encerrado_por'] ?? '—') ?></strong></div>
            <div><span>Cancelado em</span><strong><?= data_hora_br($l['finalizado_em']) ?></strong></div>
        <?php else: ?>
            <div>
                <span>Se devolver hoje</span>
                <strong><?= moeda($seDevolverHoje['total']) ?></strong>
                <small class="texto-fraco"><?= $seDevolverHoje['dias'] ?> diária(s)<?= $seDevolverHoje['atraso'] ? ', ' . $seDevolverHoje['atraso'] . ' de atraso' : '' ?></small>
            </div>
        <?php endif; ?>
    </div>

    <?php if ($assinatura = url_assinatura($l['assinatura_path'])): ?>
        <h4 style="margin-top: 20px; color: var(--azul);">Assinatura do cliente</h4>
        <img src="<?= e($assinatura) ?>" alt="Assinatura de <?= e($l['cliente']) ?>" class="assinatura-contrato">
        <p class="texto-fraco">Assinado no celular em <?= data_hora_br($l['assinada_em']) ?>.</p>
    <?php endif; ?>

    <?php if ($l['observacoes']): ?>
        <h4 style="margin-top: 20px; color: var(--azul);">Observações</h4>
        <p style="white-space: pre-line;"><?= e($l['observacoes']) ?></p>
    <?php endif; ?>
</div>

<?php if ($l['status'] === 'Em andamento' && pode('locacoes_cancelar')): ?>
    <div class="bloco nao-imprimir">
        <h2>Cancelar aluguel</h2>
        <p class="texto-fraco" style="margin-bottom: 12px;">
            Use só quando o aluguel foi registrado por engano ou o cliente desistiu. Nada é cobrado e o veículo volta a ficar disponível.
        </p>

        <form method="POST" action="<?= e(url('locacoes/cancelar.php')) ?>"
              data-confirmar="Cancelar o aluguel #<?= $id ?>? Esta ação não pode ser desfeita.">
            <?= csrf_campo() ?>
            <input type="hidden" name="id" value="<?= $id ?>">

            <div class="form-group">
                <label for="motivo">Motivo do cancelamento *</label>
                <textarea id="motivo" name="motivo" minlength="5" maxlength="500" required
                          placeholder="Ex.: cliente desistiu antes de sair com o carro"></textarea>
            </div>

            <button type="submit" class="btn-danger-lg">Cancelar aluguel</button>
        </form>
    </div>
<?php endif; ?>

<?php require RAIZ . '/includes/rodape.php'; ?>
