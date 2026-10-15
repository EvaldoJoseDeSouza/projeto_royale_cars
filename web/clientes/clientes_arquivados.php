<?php
/*
|--------------------------------------------------------------------------
| CLIENTES ARQUIVADOS
|--------------------------------------------------------------------------
| Lista exclusiva dos clientes arquivados. Daqui é possível consultar o
| histórico e reativar o cadastro.
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/clientes.php';

exigir_permissao('clientes_ver');

$busca = trim($_GET['busca'] ?? '');

[$clientes, $total, $pagina, $totalPaginas] = listar_clientes(true, $busca, 'arquivado_em.desc');
$alugueis = contar_alugueis_clientes(array_column($clientes, 'id'));

$titulo = 'Clientes arquivados';
$subtitulo = 'Cadastros fora de uso, com histórico preservado';
$menu = 'clientes';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="page-header">
    <div>
        <h2>Clientes arquivados</h2>
        <p>Arquivar não apaga nada. Reative quando o cliente voltar.</p>
    </div>

    <a href="<?= e(url('clientes/index.php')) ?>" class="btn-secondary">Voltar para ativos</a>
</div>

<form method="GET" class="filtros">
    <div class="filtro largo">
        <label for="busca">Buscar</label>
        <input type="text" id="busca" name="busca" value="<?= e($busca) ?>"
               placeholder="Nome, CPF, CNH, e-mail ou telefone">
    </div>
    <button type="submit" class="btn-primary">Buscar</button>
</form>

<div class="table-container">
    <table>
        <thead>
            <tr>
                <th>Nome</th>
                <th>CPF</th>
                <th>Telefone</th>
                <th>E-mail</th>
                <th>Aluguéis</th>
                <th>Arquivado em</th>
                <th>Ações</th>
            </tr>
        </thead>
        <tbody>
            <?php foreach ($clientes as $cliente): ?>
                <tr>
                    <td><strong><?= e($cliente['nome']) ?></strong></td>
                    <td><?= e(formatar_cpf($cliente['cpf'])) ?></td>
                    <td><?= e(formatar_telefone($cliente['telefone'])) ?></td>
                    <td><?= e($cliente['email']) ?></td>
                    <td><?= array_sum($alugueis[$cliente['id']] ?? []) ?></td>
                    <td><?= data_hora_br($cliente['arquivado_em']) ?></td>
                    <td>
                        <a href="<?= e(url('clientes/ver.php?id=' . $cliente['id'])) ?>" class="btn-small btn-claro">Histórico</a>

                        <?php if (pode('clientes_arquivar')): ?>
                            <?= botao_acao('clientes/reativar.php', ['id' => $cliente['id']], 'Reativar', 'btn-small btn-success',
                                'Reativar o cadastro de ' . $cliente['nome'] . '?') ?>
                        <?php endif; ?>
                    </td>
                </tr>
            <?php endforeach; ?>

            <?php if (!$clientes): ?>
                <tr><td colspan="7" class="empty">Nenhum cliente arquivado.</td></tr>
            <?php endif; ?>
        </tbody>
    </table>
</div>

<?= links_paginacao($pagina, $totalPaginas) ?>

<?php require RAIZ . '/includes/rodape.php'; ?>
