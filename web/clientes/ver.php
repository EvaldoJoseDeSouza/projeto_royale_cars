<?php
/*
|--------------------------------------------------------------------------
| FICHA DO CLIENTE + HISTÓRICO DE ALUGUÉIS
|--------------------------------------------------------------------------
| Funciona também para clientes arquivados: o histórico nunca é apagado.
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/clientes.php';

exigir_permissao('clientes_ver');

$id = (int) ($_GET['id'] ?? 0);
$cliente = buscar_cliente($id);

if (!$cliente) {
    flash('erro', 'Cliente não encontrado.');
    redirecionar('clientes/index.php');
}

// Os aluguéis do cliente, com o veículo "pendurado" em cada um.
// Quem não tem permissão de ver aluguéis recebe a lista vazia (regra do banco).
$locacoes = sb_select('locacoes', [
    'select'     => 'id,status,data_retirada,data_prevista,data_devolucao,valor_total,veiculos(marca,modelo,placa)',
    'cliente_id' => 'eq.' . $id,
    'order'      => 'data_retirada.desc,id.desc',
]);

// Tira o veículo da "caixinha" para as funções nome_veiculo() e formatar_placa()
foreach ($locacoes as &$l) {
    $l += $l['veiculos'] ?? [];
}
unset($l);

$totalGasto = 0;
$ativos = 0;

foreach ($locacoes as $l) {
    if ($l['status'] === 'Finalizada') {
        $totalGasto += $l['valor_total'];
    }

    if ($l['status'] === 'Em andamento') {
        $ativos++;
    }
}

$titulo = $cliente['nome'];
$subtitulo = $cliente['arquivado'] ? 'Cliente arquivado' : 'Ficha do cliente';
$menu = 'clientes';
require RAIZ . '/includes/cabecalho.php';
?>

<?php if ($cliente['arquivado']): ?>
    <div class="alert-warning">
        Cliente arquivado em <?= data_hora_br($cliente['arquivado_em']) ?>.
        Os dados e o histórico continuam guardados.
    </div>
<?php endif; ?>

<div class="page-header">
    <div>
        <h2>Dados do cliente</h2>
        <p>Cadastrado em <?= data_br($cliente['criado_em']) ?>.</p>
    </div>

    <div class="acoes-topo">
        <a href="<?= e(url($cliente['arquivado'] ? 'clientes/clientes_arquivados.php' : 'clientes/index.php')) ?>" class="btn-secondary">Voltar</a>

        <?php if (!$cliente['arquivado']): ?>
            <?php if (pode('locacoes_gerenciar')): ?>
                <a href="<?= e(url('locacoes/cadastrar.php?cliente_id=' . $id)) ?>" class="btn-primary">Novo aluguel</a>
            <?php endif; ?>

            <?php if (pode('clientes_gerenciar')): ?>
                <a href="<?= e(url('clientes/editar.php?id=' . $id)) ?>" class="btn-secondary">Editar</a>
            <?php endif; ?>
        <?php elseif (pode('clientes_arquivar')): ?>
            <?= botao_acao('clientes/reativar.php', ['id' => $id], 'Reativar cliente', 'btn-primary',
                'Reativar o cadastro de ' . $cliente['nome'] . '?') ?>
        <?php endif; ?>
    </div>
</div>

<div class="bloco">
    <div class="ficha">
        <div><span>CPF</span><strong><?= e(formatar_cpf($cliente['cpf'])) ?></strong></div>
        <div><span>Telefone</span><strong><?= e(formatar_telefone($cliente['telefone'])) ?></strong></div>
        <div><span>E-mail</span><strong><?= e($cliente['email']) ?></strong></div>
        <div><span>CNH</span><strong><?= e($cliente['cnh']) ?></strong></div>
        <div><span>Endereço</span><strong><?= e($cliente['endereco'] ?? '—') ?></strong></div>
        <div>
            <span>Validade da CNH</span>
            <strong><?= data_br($cliente['cnh_validade']) ?></strong>
            <?= situacao_cnh($cliente['cnh_validade']) ?>
        </div>
        <div>
            <span>Situação</span>
            <strong><?= $cliente['arquivado'] ? badge_status('Arquivado') : badge_status('Ativo') ?></strong>
        </div>
    </div>
</div>

<div class="dashboard-cards cards-3">
    <div class="dashboard-card">
        <div class="dashboard-card-icon"><?= icone('locacoes') ?></div>
        <div><span>Aluguéis no total</span><strong><?= count($locacoes) ?></strong></div>
    </div>
    <div class="dashboard-card azul">
        <div class="dashboard-card-icon"><?= icone('veiculos') ?></div>
        <div><span>Em andamento</span><strong><?= $ativos ?></strong></div>
    </div>
    <div class="dashboard-card verde">
        <div class="dashboard-card-icon"><?= icone('financeiro') ?></div>
        <div><span>Total já pago</span><strong><?= moeda($totalGasto) ?></strong></div>
    </div>
</div>

<div class="bloco">
    <h2>Histórico de aluguéis</h2>

    <div class="table-container">
        <table>
            <thead>
                <tr>
                    <th>#</th>
                    <th>Veículo</th>
                    <th>Retirada</th>
                    <th>Devolução prevista</th>
                    <th>Devolvido em</th>
                    <th class="numero">Valor</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($locacoes as $l): ?>
                    <tr>
                        <td>
                            <?php if (pode('locacoes_ver')): ?>
                                <a href="<?= e(url('locacoes/ver.php?id=' . $l['id'])) ?>">#<?= $l['id'] ?></a>
                            <?php else: ?>
                                #<?= $l['id'] ?>
                            <?php endif; ?>
                        </td>
                        <td><?= e(nome_veiculo($l)) ?> <span class="texto-fraco"><?= e(formatar_placa($l['placa'])) ?></span></td>
                        <td><?= data_br($l['data_retirada']) ?></td>
                        <td><?= data_br($l['data_prevista']) ?></td>
                        <td><?= data_br($l['data_devolucao']) ?></td>
                        <td class="numero"><?= moeda($l['valor_total']) ?></td>
                        <td><?= badge_status(status_locacao($l)) ?></td>
                    </tr>
                <?php endforeach; ?>

                <?php if (!$locacoes): ?>
                    <tr><td colspan="7" class="empty">Este cliente ainda não alugou nenhum veículo.</td></tr>
                <?php endif; ?>
            </tbody>
        </table>
    </div>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
