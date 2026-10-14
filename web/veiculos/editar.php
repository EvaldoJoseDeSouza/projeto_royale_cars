<?php
/*
|--------------------------------------------------------------------------
| EDITAR VEÍCULO
|--------------------------------------------------------------------------
| Mudanças de preço ficam no histórico de ações. Aluguéis já feitos
| guardam a diária da época e não mudam.
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/veiculos.php';

exigir_permissao('veiculos_gerenciar');

$id = (int) ($_GET['id'] ?? 0);
$veiculo = db_linha('SELECT * FROM veiculos WHERE id = ?', [$id]);

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

    [$dados, $erros] = validar_veiculo($_POST, $id);
    $dados['imagem'] = $veiculo['imagem'];
    $novaImagem = null;

    if (!$erros) {
        [$novaImagem, $erroImagem] = salvar_imagem_veiculo($_FILES['imagem'] ?? null);

        if ($erroImagem) {
            $erros['imagem'] = $erroImagem;
        }
    }

    if (!$erros) {
        $imagemFinal = $veiculo['imagem'];

        if ($novaImagem) {
            $imagemFinal = $novaImagem;
        } elseif (!empty($_POST['remover_imagem'])) {
            $imagemFinal = null;
        }

        try {
            db_executar(
                'UPDATE veiculos
                 SET marca = ?, modelo = ?, ano = ?, placa = ?, chassi = ?, valor_diaria = ?, imagem = ?
                 WHERE id = ?',
                [$dados['marca'], $dados['modelo'], $dados['ano'], $dados['placa'], $dados['chassi'], $dados['valor_diaria'], $imagemFinal, $id]
            );

            if ($imagemFinal !== $veiculo['imagem']) {
                apagar_imagem_veiculo($veiculo['imagem']);
            }

            $descricao = descrever_alteracoes_veiculo($veiculo, $dados);

            if ($imagemFinal !== $veiculo['imagem']) {
                $descricao .= $imagemFinal ? '; trocou a foto' : '; removeu a foto';
            }

            registrar_log('veiculos', 'editar', $id,
                'Editou o ' . nome_veiculo($dados) . ' (' . formatar_placa($dados['placa']) . "): {$descricao}.");

            flash('sucesso', 'Veículo atualizado.');
            redirecionar('veiculos/ver.php?id=' . $id);
        } catch (mysqli_sql_exception $e) {
            apagar_imagem_veiculo($novaImagem);

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
