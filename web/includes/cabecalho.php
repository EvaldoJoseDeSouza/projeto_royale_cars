<?php
/*
|--------------------------------------------------------------------------
| CABEÇALHO + MENU LATERAL (usado por todas as páginas internas)
|--------------------------------------------------------------------------
| Antes de incluir, defina:
|   $titulo    → título da página
|   $subtitulo → (opcional) texto menor abaixo do título
|   $menu      → item do menu que fica destacado
*/

$usuarioAtual = usuario_logado();
$subtitulo = $subtitulo ?? '';
$menu = $menu ?? '';

$itensMenu = [
    ['chave' => 'dashboard',   'texto' => 'Dashboard',         'link' => 'dashboard.php',            'icone' => 'inicio',     'mostrar' => true],
    ['chave' => 'alertas',     'texto' => 'Alertas',           'link' => 'alertas.php',              'icone' => 'alerta',     'mostrar' => true],
    ['chave' => 'clientes',    'texto' => 'Clientes',          'link' => 'clientes/index.php',       'icone' => 'clientes',   'mostrar' => pode('clientes_ver')],
    ['chave' => 'veiculos',    'texto' => 'Frota de veículos', 'link' => 'veiculos/index.php',       'icone' => 'veiculos',   'mostrar' => pode('veiculos_ver')],
    ['chave' => 'locacoes',    'texto' => 'Aluguéis',          'link' => 'locacoes/index.php',       'icone' => 'locacoes',   'mostrar' => pode('locacoes_ver')],
    ['chave' => 'manutencoes', 'texto' => 'Manutenção',        'link' => 'manutencoes/index.php',    'icone' => 'manutencao', 'mostrar' => pode('manutencoes')],
    ['chave' => 'financeiro',  'texto' => 'Financeiro',        'link' => 'financeiro/index.php',     'icone' => 'financeiro', 'mostrar' => pode('financeiro')],
    ['chave' => 'relatorios',  'texto' => 'Relatórios',        'link' => 'relatorios/index.php',     'icone' => 'relatorios', 'mostrar' => pode('relatorios') || pode('relatorios_financeiros')],
];

$totalAlertas = $usuarioAtual ? contar_alertas() : 0;
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= e($titulo) ?> - Royale Cars</title>
    <link rel="stylesheet" href="<?= e(url('css/style.css')) ?>">
</head>
<body>

<aside class="sidebar" id="sidebar">

    <div class="logo">
        <h2>ROYALE <span>CARS</span></h2>
        <p class="logo-subtitle">Sistema de Gestão</p>
    </div>

    <nav class="menu">
        <?php foreach ($itensMenu as $item): ?>
            <?php if ($item['mostrar']): ?>
                <a href="<?= e(url($item['link'])) ?>" class="<?= $menu === $item['chave'] ? 'active' : '' ?>">
                    <?= icone($item['icone']) ?>
                    <span><?= e($item['texto']) ?></span>
                    <?php if ($item['chave'] === 'alertas' && $totalAlertas > 0): ?>
                        <b class="menu-contador"><?= $totalAlertas ?></b>
                    <?php endif; ?>
                </a>
            <?php endif; ?>
        <?php endforeach; ?>

        <?php if (eh_chefe()): ?>
            <p class="menu-secao">Exclusivo do chefe</p>
            <a href="<?= e(url('admin/index.php')) ?>" class="<?= $menu === 'admin' ? 'active' : '' ?>">
                <?= icone('admin') ?>
                <span>Painel Administrativo</span>
            </a>
        <?php endif; ?>

        <p class="menu-secao">Conta</p>

        <a href="<?= e(url('configuracoes/index.php')) ?>" class="<?= $menu === 'configuracoes' ? 'active' : '' ?>">
            <?= icone('conta') ?>
            <span>Minha conta</span>
        </a>

        <form method="POST" action="<?= e(url('logout.php')) ?>">
            <?= csrf_campo() ?>
            <button type="submit" class="menu-sair">
                <?= icone('sair') ?>
                <span>Sair</span>
            </button>
        </form>
    </nav>

</aside>

<main class="main">

    <header class="topbar">
        <div>
            <button type="button" class="menu-mobile" data-abrir-menu aria-label="Abrir menu">☰</button>
            <h1><?= e($titulo) ?></h1>
            <?php if ($subtitulo !== ''): ?>
                <p class="topbar-subtitle"><?= e($subtitulo) ?></p>
            <?php endif; ?>
        </div>

        <?php if ($usuarioAtual): ?>
            <div class="usuario-topo">
                <div class="usuario-avatar"><?= e(mb_strtoupper(mb_substr($usuarioAtual['nome'], 0, 1))) ?></div>
                <div>
                    <strong><?= e($usuarioAtual['nome']) ?></strong>
                    <small><?= e(CARGOS[$usuarioAtual['cargo']] ?? '') ?></small>
                </div>
            </div>
        <?php endif; ?>
    </header>

    <section class="content">
        <?= mostrar_flash() ?>
