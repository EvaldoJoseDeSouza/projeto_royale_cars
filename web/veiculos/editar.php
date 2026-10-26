<?php
/*
| EDITAR VEÍCULO
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/veiculos.php';

exigir_permissao('veiculos_gerenciar');

$id = (int) ($_GET['id'] ?? 0);
$veiculo = buscar_veiculo($id);

if (!$veiculo) {
    flash('erro', 'Veículo não encontrado.');
    redirecionar('veiculos/index.php');
}

if ($veiculo['arquivado']) {
    flash('aviso', 'Este veículo está arquivado. Reative-o para poder editar.');
    redirecionar('veiculos/arquivados.php');
}

$dados = $veiculo;
$erros = [];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verificar_csrf();

    [$dados, $erros] = validar_veiculo($_POST, $veiculo);
    $dados['imagem'] = $veiculo['imagem'];
    $novaFoto = null;

    if (!$erros) {
        [$novaFoto, $erroFoto] = enviar_foto_veiculo($_FILES['imagem'] ?? null);

        if ($erroFoto) {
            $erros['imagem'] = $erroFoto;
        }
    }

    if (!$erros) {
        if ($novaFoto) {
            $dados['imagem'] = $novaFoto;
        } elseif (!empty($_POST['remover_imagem'])) {
            $dados['imagem'] = null;
        }
        [$gravado, $erros] = salvar_veiculo($dados, $id);

        if ($gravado) {
            if ($dados['imagem'] !== $veiculo['imagem']) {
                apagar_foto_veiculo($veiculo['imagem']);
            }

            flash('sucesso', 'Veículo atualizado.');
            redirecionar('veiculos/ver.php?id=' . $id);
        }

        apagar_foto_veiculo($novaFoto);
        $dados['imagem'] = $veiculo['imagem'];

        if (!$erros) {
            $erros['geral'] = 'Não foi possível salvar. O veículo pode ter sido arquivado por outra pessoa.';
        }
    }
}

$titulo = 'Editar veículo';
$subtitulo = nome_veiculo($veiculo) . ' · ' . formatar_placa($veiculo['placa']);
$menu = 'veiculos';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="form-container">
    <div class="page-header">
        <div>
            <h2>Editar veículo</h2>
            <p>Status atual: <?= badge_status($veiculo['status']) ?> (muda automaticamente)</p>
        </div>
        <a href="<?= e(url('veiculos/ver.php?id=' . $id)) ?>" class="btn-secondary">Voltar</a>
    </div>

    <?php if ($veiculo['status'] === 'Alugado'): ?>
        <div class="alert-info">
            Este veículo está alugado. Se mudar a diária agora, o aluguel atual continua com o valor combinado.
        </div>
    <?php endif; ?>

    <?= $erros ? mostrar_erros(array_unique(array_values($erros))) : '' ?>

    <form method="POST" enctype="multipart/form-data" novalidate>
        <?= csrf_campo() ?>
        <?php require RAIZ . '/includes/form_veiculo.php'; ?>

        <div class="form-actions">
            <button type="submit" class="btn-primary">Salvar alterações</button>
            <a href="<?= e(url('veiculos/ver.php?id=' . $id)) ?>" class="btn-secondary">Cancelar</a>
        </div>
    </form>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
