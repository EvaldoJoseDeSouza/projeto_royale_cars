<?php
/*
|--------------------------------------------------------------------------
| CADASTRAR CLIENTE
|--------------------------------------------------------------------------
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
        try {
            db_executar(
                'INSERT INTO clientes (nome, cpf, cnh, cnh_validade, email, telefone)
                 VALUES (?, ?, ?, ?, ?, ?)',
                [$dados['nome'], $dados['cpf'], $dados['cnh'], $dados['cnh_validade'], $dados['email'], $dados['telefone']]
            );

            $id = db_ultimo_id();

            registrar_log('clientes', 'cadastrar', $id,
                "Cadastrou o cliente {$dados['nome']} (CPF " . formatar_cpf($dados['cpf']) . ').');

            flash('sucesso', "Cliente {$dados['nome']} cadastrado com sucesso!");

            if ($dados['cnh_validade'] < date('Y-m-d')) {
                flash('aviso', 'Atenção: a CNH deste cliente está vencida. Ele só poderá alugar depois de atualizar a validade.');
            }

            redirecionar('clientes/ver.php?id=' . $id);
        } catch (mysqli_sql_exception $e) {
            // Segunda barreira: o banco recusou (duplicado ou regra CHECK)
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
