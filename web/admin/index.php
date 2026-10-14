<?php
/*
|--------------------------------------------------------------------------
| PAINEL ADMINISTRATIVO (exclusivo do chefe)
|--------------------------------------------------------------------------
*/

require __DIR__ . '/../includes/bootstrap.php';

exigir_chefe();

$usuariosAtivos = (int) db_valor("SELECT COUNT(*) FROM usuarios WHERE ativo = 1 AND cargo <> 'chefe'");
$usuariosInativos = (int) db_valor('SELECT COUNT(*) FROM usuarios WHERE ativo = 0');
$acoesHoje = (int) db_valor('SELECT COUNT(*) FROM logs WHERE criado_em >= CURDATE()');
$falhas24h = (int) db_valor('SELECT COUNT(*) FROM login_tentativas WHERE sucesso = 0 AND criado_em > DATE_SUB(NOW(), INTERVAL 24 HOUR)');

$ultimasAcoes = db_todos(
    'SELECT l.*, u.nome AS usuario
     FROM logs l
     LEFT JOIN usuarios u ON u.id = l.usuario_id
     WHERE l.modulo <> \'seguranca\' OR l.acao NOT IN (\'login\', \'logout\')
     ORDER BY l.id DESC
     LIMIT 10'
);

$equipe = db_todos(
    "SELECT u.id, u.nome, u.cargo, u.ativo, u.ultimo_acesso,
            (SELECT COUNT(*) FROM logs l WHERE l.usuario_id = u.id AND l.criado_em > DATE_SUB(NOW(), INTERVAL 30 DAY)) AS acoes_30d
     FROM usuarios u
     ORDER BY u.ativo DESC, FIELD(u.cargo, 'chefe', 'gerente', 'funcionario'), u.nome"
);

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
                            Último acesso: <?= data_hora_br($u['ultimo_acesso']) ?> · <?= (int) $u['acoes_30d'] ?> ação(ões) em 30 dias
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
                        <strong><?= e($a['usuario'] ?? 'Sistema') ?></strong>
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
