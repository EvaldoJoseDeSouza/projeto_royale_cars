<?php
/*
|--------------------------------------------------------------------------
| CADASTRAR VEÍCULO
|--------------------------------------------------------------------------
| Todo veículo novo entra como "Disponível".
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/veiculos.php';

exigir_permissao('veiculos_gerenciar');

$dados = [];
$erros = [];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verificar_csrf();

    [$dados, $erros] = validar_veiculo($_POST);

    if (!$erros) {
        [$foto, $erroFoto] = enviar_foto_veiculo($_FILES['imagem'] ?? null);

        if ($erroFoto) {
            $erros['imagem'] = $erroFoto;
        }
    }

    if (!$erros) {
        // O banco põe o status "Disponível" e grava o histórico sozinho
        [$veiculo, $erros] = salvar_veiculo($dados + ['imagem' => $foto]);

        if ($veiculo) {
            flash('sucesso', 'Veículo cadastrado e disponível para aluguel.');
            redirecionar('veiculos/ver.php?id=' . $veiculo['id']);
        }

        // O banco recusou: a foto que já subiu ficaria "órfã" no Storage
        apagar_foto_veiculo($foto);
    }
}

$titulo = 'Cadastrar veículo';
$subtitulo = 'Adicionar à frota';
$menu = 'veiculos';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="form-container">
    <div class="page-header">
        <div>
            <h2>Novo veículo</h2>
            <p>O veículo entra na frota como <strong>Disponível</strong>.</p>
        </div>
        <a href="<?= e(url('veiculos/index.php')) ?>" class="btn-secondary">Voltar</a>
    </div>

    <?= $erros ? mostrar_erros(array_unique(array_values($erros))) : '' ?>

    <form method="POST" enctype="multipart/form-data" novalidate>
        <?= csrf_campo() ?>
        <?php require RAIZ . '/includes/form_veiculo.php'; ?>

        <div class="form-actions">
            <button type="submit" class="btn-primary">Cadastrar veículo</button>
            <a href="<?= e(url('veiculos/index.php')) ?>" class="btn-secondary">Cancelar</a>
        </div>
    </form>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
