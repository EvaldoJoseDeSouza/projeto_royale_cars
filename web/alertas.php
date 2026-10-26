<?php
/*
| ALERTAS AUTOMÁTICOS
*/

require __DIR__ . '/includes/bootstrap.php';

exigir_login();

$alertas = buscar_alertas();
$total = contar_alertas();

$urgente = fn (string $texto) => (bool) preg_match('/atraso|venceu|vencida|tentativa/i', $texto);

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

<?php foreach (TIPOS_ALERTA as $tipo => $info): ?>
    <?php if (!$alertas[$tipo]) continue; ?>

    <div class="bloco">
        <div class="alerta-titulo">
            <h2><?= e($info['titulo']) ?></h2>
            <span class="contador"><?= count($alertas[$tipo]) ?></span>
        </div>
        <p class="texto-fraco"><?= e($info['ajuda']) ?></p>

        <ul class="lista-alertas">
            <?php foreach ($alertas[$tipo] as $a): ?>
                <li>
                    <div>
                        <strong><?= e($a['titulo']) ?></strong><br>
                        <span class="<?= $urgente($a['detalhe']) ? 'texto-vermelho' : 'texto-fraco' ?>"><?= e($a['detalhe']) ?></span>
                    </div>
                    <?php if (pode_abrir_alerta($tipo)): ?>
                        <a href="<?= e(url(link_alerta($a))) ?>" class="btn-small"><?= e($info['botao']) ?></a>
                    <?php endif; ?>
                </li>
            <?php endforeach; ?>
        </ul>
    </div>
<?php endforeach; ?>

<?php require RAIZ . '/includes/rodape.php'; ?>
