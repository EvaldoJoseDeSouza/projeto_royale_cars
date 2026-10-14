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
        [$imagem, $erroImagem] = salvar_imagem_veiculo($_FILES['imagem'] ?? null);

        if ($erroImagem) {
            $erros['imagem'] = $erroImagem;
        }
    }

    if (!$erros) {
        try {
            db_executar(
                "INSERT INTO veiculos (marca, modelo, ano, placa, chassi, valor_diaria, imagem, status)
                 VALUES (?, ?, ?, ?, ?, ?, ?, 'Disponível')",
                [$dados['marca'], $dados['modelo'], $dados['ano'], $dados['placa'], $dados['chassi'], $dados['valor_diaria'], $imagem]
            );

            $id = db_ultimo_id();

            registrar_log('veiculos', 'cadastrar', $id,
                'Cadastrou o veículo ' . nome_veiculo($dados) . ' (' . formatar_placa($dados['placa']) . '), diária de ' . moeda($dados['valor_diaria']) . '.');

            flash('sucesso', 'Veículo cadastrado e disponível para aluguel.');
            redirecionar('veiculos/ver.php?id=' . $id);
        } catch (mysqli_sql_exception $e) {
            apagar_imagem_veiculo($imagem);

            if ($campo = campo_duplicado($e)) {
                $erros[$campo] = 'Este valor já está cadastrado em outro veículo.';
            } elseif (violou_regra_banco($e)) {
                $erros[] = 'O banco de dados recusou os dados. Confira os campos.';
            } else {
                throw $e;
            }
        }
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
