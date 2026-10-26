<?php
/*
CADASTRAR CLIENTE
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/clientes.php';

exigir_permissao('clientes_gerenciar');

$dados = [];
$erros = [];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verificar_csrf();

    [$dados, $erros] = validar_cliente($_POST);

    if (!$erros) {
        [$cliente, $erros] = salvar_cliente($dados);

        if ($cliente) {
            flash('sucesso', "Cliente {$cliente['nome']} cadastrado com sucesso!");

            if ($cliente['cnh_validade'] < date('Y-m-d')) {
                flash('aviso', 'Atenção: a CNH deste cliente está vencida. Ele só poderá alugar depois de atualizar a validade.');
            }

            redirecionar('clientes/ver.php?id=' . $cliente['id']);
        }
    }
}

$titulo = 'Cadastrar cliente';
$subtitulo = 'Todos os documentos são conferidos automaticamente';
$menu = 'clientes';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="form-container">
    <div class="page-header">
        <div>
            <h2>Novo cliente</h2>
            <p>Campos com * são obrigatórios.</p>
        </div>
        <a href="<?= e(url('clientes/index.php')) ?>" class="btn-secondary">Voltar</a>
    </div>

    <?= $erros ? mostrar_erros(array_unique(array_values($erros))) : '' ?>

    <form method="POST" novalidate>
        <?= csrf_campo() ?>
        <?php require RAIZ . '/includes/form_cliente.php'; ?>

        <div class="form-actions">
            <button type="submit" class="btn-primary">Cadastrar cliente</button>
            <a href="<?= e(url('clientes/index.php')) ?>" class="btn-secondary">Cancelar</a>
        </div>
    </form>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
