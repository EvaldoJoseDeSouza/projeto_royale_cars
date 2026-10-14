<?php
/*
|--------------------------------------------------------------------------
| ALERTAS AUTOMÁTICOS
|--------------------------------------------------------------------------
| - Aluguéis atrasados
| - Devoluções nos próximos dias
| - Veículos na oficina (e previsão de liberação vencida)
| - Clientes com CNH vencida ou vencendo (documentos pendentes)
| - Tentativas suspeitas de login (só o chefe vê)
*/

require __DIR__ . '/includes/bootstrap.php';

exigir_login();

$alertas = buscar_alertas();
$total = contar_alertas();

$titulo = 'Alertas';
$subtitulo = $total ? "{$total} item(ns) pedindo atenção" : 'Nada pendente';
$menu = 'alertas';
require RAIZ . '/includes/cabecalho.php';
?>

<?php if (!$total): ?>
    <div class="estado-vazio">
        <h2>Tudo em dia!</h2>
        <p>Não há atrasos, devoluções próximas, veículos parados ou documentos vencendo.</p>
    </div>
<?php endif; ?>

<?php if ($alertas['atrasadas']): ?>
    <div class="bloco">
        <div class="alerta-titulo">
            <h2>Aluguéis atrasados</h2>
            <span class="contador"><?= count($alertas['atrasadas']) ?></span>
        </div>
        <p class="texto-fraco">Entre em contato com o cliente. Cada dia de atraso é cobrado pela diária combinada.</p>

        <ul class="lista-alertas">
            <?php foreach ($alertas['atrasadas'] as $a): ?>
                <li>
                    <div>
                        <strong><?= e(nome_veiculo($a)) ?></strong> (<?= e(formatar_placa($a['placa'])) ?>) com <?= e($a['cliente']) ?> ·
                        <?= e(formatar_telefone($a['telefone'])) ?><br>
                        <span class="texto-vermelho">
                            Devolução era <?= data_br($a['data_prevista']) ?> · <?= (int) $a['dias_atraso'] ?> dia(s) de atraso
                            (+<?= moeda($a['dias_atraso'] * $a['valor_diaria']) ?>)
                        </span>
                    </div>
                    <a href="<?= e(url('locacoes/ver.php?id=' . $a['id'])) ?>" class="btn-small">Abrir</a>
                </li>
            <?php endforeach; ?>
        </ul>
    </div>
<?php endif; ?>

<?php if ($alertas['devolucoes_proximas']): ?>
    <div class="bloco">
        <div class="alerta-titulo">
            <h2>Devoluções próximas</h2>
            <span class="contador"><?= count($alertas['devolucoes_proximas']) ?></span>
        </div>

        <ul class="lista-alertas">
            <?php foreach ($alertas['devolucoes_proximas'] as $a): ?>
                <li>
                    <div>
                        <strong><?= e(nome_veiculo($a)) ?></strong> (<?= e(formatar_placa($a['placa'])) ?>) com <?= e($a['cliente']) ?><br>
                        <span class="texto-fraco">
                            <?= $a['faltam'] == 0 ? 'Devolução hoje' : ($a['faltam'] == 1 ? 'Devolução amanhã' : 'Devolução em ' . (int) $a['faltam'] . ' dias') ?>
                            (<?= data_br($a['data_prevista']) ?>)
                        </span>
                    </div>
                    <a href="<?= e(url('locacoes/ver.php?id=' . $a['id'])) ?>" class="btn-small">Abrir</a>
                </li>
            <?php endforeach; ?>
        </ul>
    </div>
<?php endif; ?>

<?php if ($alertas['em_manutencao']): ?>
    <div class="bloco">
        <div class="alerta-titulo">
            <h2>Veículos em manutenção</h2>
            <span class="contador"><?= count($alertas['em_manutencao']) ?></span>
        </div>
        <p class="texto-fraco">Estes veículos estão bloqueados para aluguel.</p>

        <ul class="lista-alertas">
            <?php foreach ($alertas['em_manutencao'] as $a): ?>
                <li>
                    <div>
                        <strong><?= e(nome_veiculo($a)) ?></strong> (<?= e(formatar_placa($a['placa'])) ?>) · <?= e($a['defeito']) ?><br>
                        <span class="<?= $a['previsao_vencida'] ? 'texto-vermelho' : 'texto-fraco' ?>">
                            Na oficina há <?= (int) $a['dias_parado'] ?> dia(s)
                            <?php if ($a['previsao_liberacao']): ?>
                                · previsão <?= data_br($a['previsao_liberacao']) ?><?= $a['previsao_vencida'] ? ' (vencida)' : '' ?>
                            <?php endif; ?>
                        </span>
                    </div>
                    <?php if (pode('manutencoes')): ?>
                        <a href="<?= e(url('manutencoes/concluir.php?id=' . $a['id'])) ?>" class="btn-small">Liberar</a>
                    <?php endif; ?>
                </li>
            <?php endforeach; ?>
        </ul>
    </div>
<?php endif; ?>

<?php if ($alertas['cnh']): ?>
    <div class="bloco">
        <div class="alerta-titulo">
            <h2>CNH vencida ou vencendo</h2>
            <span class="contador"><?= count($alertas['cnh']) ?></span>
        </div>
        <p class="texto-fraco">Cadastros que precisam de conferência: clientes com CNH vencida não podem alugar.</p>

        <ul class="lista-alertas">
            <?php foreach ($alertas['cnh'] as $a): ?>
                <li>
                    <div>
                        <strong><?= e($a['nome']) ?></strong> · <?= e(formatar_telefone($a['telefone'])) ?><br>
                        <span class="<?= $a['dias'] < 0 ? 'texto-vermelho' : 'texto-fraco' ?>">
                            <?= $a['dias'] < 0 ? 'Venceu em ' : 'Vence em ' ?><?= data_br($a['cnh_validade']) ?>
                            <?= $a['dias'] >= 0 ? '(' . (int) $a['dias'] . ' dia(s))' : '' ?>
                        </span>
                    </div>
                    <?php if (pode('clientes_gerenciar')): ?>
                        <a href="<?= e(url('clientes/editar.php?id=' . $a['id'])) ?>" class="btn-small">Atualizar</a>
                    <?php endif; ?>
                </li>
            <?php endforeach; ?>
        </ul>
    </div>
<?php endif; ?>

<?php if ($alertas['login_suspeito']): ?>
    <div class="bloco">
        <div class="alerta-titulo">
            <h2>Tentativas suspeitas de login (24h)</h2>
            <span class="contador"><?= count($alertas['login_suspeito']) ?></span>
        </div>
        <p class="texto-fraco">Três ou mais senhas erradas seguidas do mesmo e-mail e IP.</p>

        <ul class="lista-alertas">
            <?php foreach ($alertas['login_suspeito'] as $a): ?>
                <li>
                    <div>
                        <strong><?= e($a['email']) ?></strong> · IP <?= e($a['ip']) ?><br>
                        <span class="texto-vermelho"><?= (int) $a['falhas'] ?> falha(s), a última em <?= data_hora_br($a['ultima']) ?></span>
                    </div>
                    <a href="<?= e(url('admin/tentativas.php')) ?>" class="btn-small">Detalhes</a>
                </li>
            <?php endforeach; ?>
        </ul>
    </div>
<?php endif; ?>

<?php require RAIZ . '/includes/rodape.php'; ?>
