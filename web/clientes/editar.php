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
$cliente = db_linha('SELECT * FROM clientes WHERE id = ?', [$id]);

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

    [$dados, $erros] = validar_cliente($_POST, $id);

    if (!$erros) {
        try {
            db_executar(
                'UPDATE clientes
                 SET nome = ?, cpf = ?, cnh = ?, cnh_validade = ?, email = ?, telefone = ?
                 WHERE id = ?',
                [$dados['nome'], $dados['cpf'], $dados['cnh'], $dados['cnh_validade'], $dados['email'], $dados['telefone'], $id]
            );

            registrar_log('clientes', 'editar', $id,
                "Editou o cliente {$dados['nome']}: " . descrever_alteracoes_cliente($cliente, $dados) . '.');

            flash('sucesso', 'Dados do cliente atualizados.');
            redirecionar('clientes/ver.php?id=' . $id);
        } catch (mysqli_sql_exception $e) {
            if ($campo = campo_duplicado($e)) {
                $erros[$campo] = 'Este valor já está cadastrado para outro cliente.';
            } elseif (violou_regra_banco($e)) {
                $erros[] = 'O banco de dados recusou os dados. Confira os campos.';
            } else {
                throw $e;
            }
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
