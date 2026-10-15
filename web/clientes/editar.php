<?php
/*
|--------------------------------------------------------------------------
| EDITAR CLIENTE
|--------------------------------------------------------------------------
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/clientes.php';

exigir_permissao('clientes_gerenciar');

$id = (int) ($_GET['id'] ?? 0);
$cliente = buscar_cliente($id);

if (!$cliente) {
    flash('erro', 'Cliente não encontrado.');
    redirecionar('clientes/index.php');
}

if ($cliente['arquivado']) {
    flash('aviso', 'Este cliente está arquivado. Reative o cadastro para poder editar.');
    redirecionar('clientes/clientes_arquivados.php');
}

$dados = $cliente;
$erros = [];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verificar_csrf();

    [$dados, $erros] = validar_cliente($_POST);

    if (!$erros) {
        // O banco grava no histórico o que mudou ("telefone: ... → ...")
        [$gravado, $erros] = salvar_cliente($dados, $id);

        if ($gravado) {
            flash('sucesso', 'Dados do cliente atualizados.');

            if ($gravado['cnh_validade'] < date('Y-m-d')) {
                flash('aviso', 'Atenção: a CNH deste cliente está vencida. Ele só poderá alugar depois de atualizar a validade.');
            }

            redirecionar('clientes/ver.php?id=' . $id);
        } elseif (!$erros) {
            $erros['geral'] = 'Não foi possível salvar. O cliente pode ter sido arquivado por outra pessoa.';
        }
    }
}

$titulo = 'Editar cliente';
$subtitulo = $cliente['nome'];
$menu = 'clientes';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="form-container">
    <div class="page-header">
        <div>
            <h2>Editar dados</h2>
            <p>As alterações ficam registradas no histórico de ações.</p>
        </div>
        <a href="<?= e(url('clientes/ver.php?id=' . $id)) ?>" class="btn-secondary">Voltar</a>
    </div>

    <?= $erros ? mostrar_erros(array_unique(array_values($erros))) : '' ?>

    <form method="POST" novalidate>
        <?= csrf_campo() ?>
        <?php require RAIZ . '/includes/form_cliente.php'; ?>

        <div class="form-actions">
            <button type="submit" class="btn-primary">Salvar alterações</button>
            <a href="<?= e(url('clientes/ver.php?id=' . $id)) ?>" class="btn-secondary">Cancelar</a>
        </div>
    </form>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
