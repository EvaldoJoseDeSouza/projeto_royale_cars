<?php
/*
|--------------------------------------------------------------------------
| PAINEL ADMINISTRATIVO (exclusivo do chefe)
|--------------------------------------------------------------------------
*/

require __DIR__ . '/../includes/bootstrap.php';

require RAIZ . '/includes/usuarios.php';

exigir_chefe();

$equipe = listar_equipe();
$usuariosAtivos = count(array_filter($equipe, fn ($u) => $u['ativo'] && $u['cargo'] !== 'chefe'));
$usuariosInativos = count(array_filter($equipe, fn ($u) => !$u['ativo']));

// Horários do banco com o fuso de Brasília (-03:00), para "hoje" e "24 h" baterem com o relógio daqui
$inicioDeHoje = date('Y-m-d') . 'T00:00:00-03:00';
$acoesHoje = sb_contar('logs', ['criado_em' => 'gte.' . $inicioDeHoje]);
$falhas24h = sb_contar('login_tentativas', ['sucesso' => 'eq.false', 'criado_em' => 'gte.' . date('c', time() - 86400)]);

// As 10 últimas ações, sem as entradas no sistema (que são muitas)
$ultimasAcoes = sb_select('logs', [
    'select' => 'id,descricao,criado_em,perfis(nome)',
    'or'     => '(modulo.neq.seguranca,acao.neq.login)',
    'order'  => 'id.desc',
    'limit'  => 10,
]);

// Quantas ações cada pessoa fez nos últimos 30 dias
$acoes30d = [];

foreach (sb_select('logs', ['select' => 'usuario_id', 'criado_em' => 'gte.' . date('c', time() - 30 * 86400)]) as $l) {
    $acoes30d[$l['usuario_id']] = ($acoes30d[$l['usuario_id']] ?? 0) + 1;
}

$titulo = 'Painel Administrativo';
$subtitulo = 'Equipe, permissões e auditoria';
$menu = 'admin';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="page-header">
    <div>
        <h2>Área exclusiva do chefe</h2>
        <p>Cadastre a equipe, defina o que cada pessoa pode fazer e acompanhe tudo o que acontece no sistema.</p>
    </div>
    <a href="<?= e(url('admin/usuario_form.php')) ?>" class="btn-primary">+ Cadastrar funcionário</a>
</div>

<div class="dashboard-cards">
    <a href="<?= e(url('admin/usuarios.php')) ?>" class="dashboard-card verde">
        <div class="dashboard-card-icon"><?= icone('clientes') ?></div>
        <div><span>Funcionários e gerentes ativos</span><strong><?= $usuariosAtivos ?></strong><small><?= $usuariosInativos ?> desativado(s)</small></div>
    </a>

    <a href="<?= e(url('admin/logs.php?de=' . date('Y-m-d'))) ?>" class="dashboard-card azul">
        <div class="dashboard-card-icon"><?= icone('relatorios') ?></div>
        <div><span>Ações registradas hoje</span><strong><?= $acoesHoje ?></strong><small>histórico completo de ações</small></div>
    </a>

    <a href="<?= e(url('admin/tentativas.php?falhas=1')) ?>" class="dashboard-card <?= $falhas24h ? 'vermelho' : 'verde' ?>">
        <div class="dashboard-card-icon"><?= icone('admin') ?></div>
        <div><span>Logins com erro (24h)</span><strong><?= $falhas24h ?></strong><small>tentativas de acesso</small></div>
    </a>

    <a href="<?= e(url('relatorios/index.php')) ?>" class="dashboard-card">
        <div class="dashboard-card-icon"><?= icone('financeiro') ?></div>
        <div><span>Relatórios</span><strong>Abrir</strong><small>clientes, frota, aluguéis e faturamento</small></div>
    </a>
</div>

<div class="grade-2">
    <div class="bloco">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px;">
            <h2 style="margin: 0;">Equipe</h2>
            <a href="<?= e(url('admin/usuarios.php')) ?>" class="btn-small btn-claro">Gerenciar</a>
        </div>

        <ul class="lista-alertas">
            <?php foreach ($equipe as $u): ?>
                <li>
                    <div>
                        <strong><?= e($u['nome']) ?></strong> · <?= e(CARGOS[$u['cargo']]) ?><br>
                        <span class="texto-fraco">
                            Último acesso: <?= data_hora_br($u['ultimo_acesso']) ?> · <?= $acoes30d[$u['id']] ?? 0 ?> ação(ões) em 30 dias
                        </span>
                    </div>
                    <?= badge_status($u['ativo'] ? 'Ativo' : 'Inativo') ?>
                </li>
            <?php endforeach; ?>
        </ul>
    </div>

    <div class="bloco">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px;">
            <h2 style="margin: 0;">Últimas ações</h2>
            <a href="<?= e(url('admin/logs.php')) ?>" class="btn-small btn-claro">Ver histórico</a>
        </div>

        <ul class="lista-alertas">
            <?php foreach ($ultimasAcoes as $a): ?>
                <li>
                    <div>
                        <strong><?= e($a['perfis']['nome'] ?? 'Sistema') ?></strong>
                        <span class="texto-fraco">· <?= data_hora_br($a['criado_em']) ?></span><br>
                        <?= e($a['descricao']) ?>
                    </div>
                </li>
            <?php endforeach; ?>
            <?php if (!$ultimasAcoes): ?>
                <li><span class="texto-fraco">Nenhuma ação registrada.</span></li>
            <?php endif; ?>
        </ul>
    </div>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
