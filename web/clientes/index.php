<?php
/*
| CLIENTES ATIVOS
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/clientes.php';

exigir_permissao('clientes_ver');

$busca = trim($_GET['busca'] ?? '');

[$clientes, $total, $pagina, $totalPaginas] = listar_clientes(false, $busca, 'nome.asc');
$alugueis = contar_alugueis_clientes(array_column($clientes, 'id'));
$totalArquivados = sb_contar('clientes', ['arquivado' => 'eq.true']);

$titulo = 'Clientes';
$subtitulo = 'Cadastro de clientes da locadora';
$menu = 'clientes';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="page-header">
    <div>
        <h2>Clientes ativos</h2>
        <p><?= $total ?> cliente(s) encontrado(s).</p>
    </div>

    <div class="acoes-topo">
        <a href="<?= e(url('clientes/clientes_arquivados.php')) ?>" class="btn-secondary">
            Arquivados (<?= $totalArquivados ?>)
        </a>

        <?php if (pode('clientes_gerenciar')): ?>
            <a href="<?= e(url('clientes/cadastrar.php')) ?>" class="btn-primary">+ Cadastrar cliente</a>
        <?php endif; ?>
    </div>
</div>

<form method="GET" class="filtros">
    <div class="filtro largo">
        <label for="busca">Buscar</label>
        <input type="text" id="busca" name="busca" value="<?= e($busca) ?>"
               placeholder="Nome, CPF, CNH, e-mail ou telefone">
    </div>
    <button type="submit" class="btn-primary">Buscar</button>
    <?php if ($busca !== ''): ?>
        <a href="<?= e(url('clientes/index.php')) ?>" class="btn-secondary">Limpar</a>
    <?php endif; ?>
</form>

<div class="table-container">
    <table>
        <thead>
            <tr>
                <th>Nome</th>
                <th>CPF</th>
                <th>Telefone</th>
                <th>E-mail</th>
                <th>CNH</th>
                <th>Aluguéis</th>
                <th>Ações</th>
            </tr>
        </thead>
        <tbody>
            <?php foreach ($clientes as $cliente): ?>
                <?php
                $ativos = $alugueis[$cliente['id']]['Em andamento'] ?? 0;
                $feitos = $alugueis[$cliente['id']]['Finalizada'] ?? 0;
                ?>
                <tr>
                    <td><strong><?= e($cliente['nome']) ?></strong></td>
                    <td><?= e(formatar_cpf($cliente['cpf'])) ?></td>
                    <td><?= e(formatar_telefone($cliente['telefone'])) ?></td>
                    <td><?= e($cliente['email']) ?></td>
                    <td>
                        <?= data_br($cliente['cnh_validade']) ?>
                        <?= situacao_cnh($cliente['cnh_validade']) ?>
                    </td>
                    <td>
                        <?php if ($ativos > 0): ?>
                            <?= badge_status('Em andamento') ?>
                        <?php else: ?>
                            <span class="texto-fraco"><?= $feitos ?> concluído(s)</span>
                        <?php endif; ?>
                    </td>
                    <td>
                        <a href="<?= e(url('clientes/ver.php?id=' . $cliente['id'])) ?>" class="btn-small btn-claro">Ver</a>

                        <?php if (pode('clientes_gerenciar')): ?>
                            <a href="<?= e(url('clientes/editar.php?id=' . $cliente['id'])) ?>" class="btn-small">Editar</a>
                        <?php endif; ?>

                        <?php if (pode('clientes_arquivar') && $ativos === 0): ?>
                            <?= botao_acao('clientes/arquivar.php', ['id' => $cliente['id']], 'Arquivar', 'btn-small btn-danger',
                                'Arquivar o cliente ' . $cliente['nome'] . '? O histórico de aluguéis será mantido e ele poderá ser reativado depois.') ?>
                        <?php endif; ?>
                    </td>
                </tr>
            <?php endforeach; ?>

            <?php if (!$clientes): ?>
                <tr><td colspan="7" class="empty">Nenhum cliente encontrado.</td></tr>
            <?php endif; ?>
        </tbody>
    </table>
</div>

<?= links_paginacao($pagina, $totalPaginas) ?>

<?php require RAIZ . '/includes/rodape.php'; ?>
