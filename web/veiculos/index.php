<?php
/*
|--------------------------------------------------------------------------
| FROTA DE VEÍCULOS
|--------------------------------------------------------------------------
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/veiculos.php';

exigir_permissao('veiculos_ver');

$busca = trim($_GET['busca'] ?? '');
$status = $_GET['status'] ?? '';

if (!in_array($status, STATUS_VEICULO, true)) {
    $status = '';
}

$where = 'v.arquivado = 0';
$parametros = [];

if ($busca !== '') {
    $where .= ' AND (v.marca LIKE ? OR v.modelo LIKE ? OR v.placa LIKE ? OR v.chassi LIKE ?)';
    $placaBusca = str_replace('-', '', strtoupper($busca));
    array_push($parametros, "%{$busca}%", "%{$busca}%", "%{$placaBusca}%", "%{$placaBusca}%");
}

// Contagem por status para as abas
$contagem = ['' => 0];

foreach (STATUS_VEICULO as $s) {
    $contagem[$s] = 0;
}

foreach (db_todos("SELECT v.status, COUNT(*) AS total FROM veiculos v WHERE {$where} GROUP BY v.status", $parametros) as $linha) {
    $contagem[$linha['status']] = (int) $linha['total'];
    $contagem[''] += (int) $linha['total'];
}

if ($status !== '') {
    $where .= ' AND v.status = ?';
    $parametros[] = $status;
}

$veiculos = db_todos(
    "SELECT v.*,
            (SELECT l.data_prevista FROM locacoes l
              WHERE l.veiculo_id = v.id AND l.status = 'Em andamento' LIMIT 1) AS devolucao_prevista
     FROM veiculos v
     WHERE {$where}
     ORDER BY FIELD(v.status, 'Disponível', 'Alugado', 'Em manutenção'), v.marca, v.modelo",
    $parametros
);

$totalArquivados = (int) db_valor('SELECT COUNT(*) FROM veiculos WHERE arquivado = 1');

$titulo = 'Frota de veículos';
$subtitulo = 'Disponíveis, alugados e em manutenção';
$menu = 'veiculos';
require RAIZ . '/includes/cabecalho.php';

$linkAba = fn (string $s) => e(url('veiculos/index.php?' . http_build_query(array_filter(['status' => $s, 'busca' => $busca]))));
?>

<div class="page-header">
    <div>
        <h2>Veículos da frota</h2>
        <p>O status muda sozinho com os aluguéis e as manutenções.</p>
    </div>

    <div class="acoes-topo">
        <a href="<?= e(url('veiculos/arquivados.php')) ?>" class="btn-secondary">Arquivados (<?= $totalArquivados ?>)</a>

        <?php if (pode('veiculos_gerenciar')): ?>
            <a href="<?= e(url('veiculos/cadastrar.php')) ?>" class="btn-primary">+ Cadastrar veículo</a>
        <?php endif; ?>
    </div>
</div>

<form method="GET" class="filtros">
    <input type="hidden" name="status" value="<?= e($status) ?>">
    <div class="filtro largo">
        <label for="busca">Buscar</label>
        <input type="text" id="busca" name="busca" value="<?= e($busca) ?>" placeholder="Marca, modelo, placa ou chassi">
    </div>
    <button type="submit" class="btn-primary">Buscar</button>
</form>

<nav class="abas">
    <a href="<?= $linkAba('') ?>" class="<?= $status === '' ? 'ativa' : '' ?>">Todos <b><?= $contagem[''] ?></b></a>
    <?php foreach (STATUS_VEICULO as $s): ?>
        <a href="<?= $linkAba($s) ?>" class="<?= $status === $s ? 'ativa' : '' ?>"><?= e($s) ?> <b><?= $contagem[$s] ?></b></a>
    <?php endforeach; ?>
</nav>

<div class="table-container">
    <table>
        <thead>
            <tr>
                <th></th>
                <th>Veículo</th>
                <th>Ano</th>
                <th>Placa</th>
                <th>Chassi</th>
                <th class="numero">Diária</th>
                <th>Status</th>
                <th>Ações</th>
            </tr>
        </thead>
        <tbody>
            <?php foreach ($veiculos as $veiculo): ?>
                <tr>
                    <td><?= imagem_veiculo($veiculo) ?></td>
                    <td><strong><?= e(nome_veiculo($veiculo)) ?></strong></td>
                    <td><?= (int) $veiculo['ano'] ?></td>
                    <td class="nowrap"><?= e(formatar_placa($veiculo['placa'])) ?></td>
                    <td class="texto-fraco"><?= e($veiculo['chassi']) ?></td>
                    <td class="numero"><?= moeda($veiculo['valor_diaria']) ?></td>
                    <td>
                        <?= badge_status($veiculo['status']) ?>
                        <?php if ($veiculo['devolucao_prevista']): ?>
                            <br><small class="<?= $veiculo['devolucao_prevista'] < date('Y-m-d') ? 'texto-vermelho' : 'texto-fraco' ?>">
                                volta <?= data_br($veiculo['devolucao_prevista']) ?>
                            </small>
                        <?php endif; ?>
                    </td>
                    <td>
                        <a href="<?= e(url('veiculos/ver.php?id=' . $veiculo['id'])) ?>" class="btn-small btn-claro">Ver</a>

                        <?php if (pode('veiculos_gerenciar')): ?>
                            <a href="<?= e(url('veiculos/editar.php?id=' . $veiculo['id'])) ?>" class="btn-small">Editar</a>
                        <?php endif; ?>

                        <?php if ($veiculo['status'] === 'Disponível' && pode('locacoes_gerenciar')): ?>
                            <a href="<?= e(url('locacoes/cadastrar.php?veiculo_id=' . $veiculo['id'])) ?>" class="btn-small btn-success">Alugar</a>
                        <?php endif; ?>

                        <?php if ($veiculo['status'] === 'Disponível' && pode('veiculos_arquivar')): ?>
                            <?= botao_acao('veiculos/arquivar.php', ['id' => $veiculo['id']], 'Arquivar', 'btn-small btn-danger',
                                'Arquivar o ' . nome_veiculo($veiculo) . '? Ele sai da frota, mas o histórico é mantido.') ?>
                        <?php endif; ?>
                    </td>
                </tr>
            <?php endforeach; ?>

            <?php if (!$veiculos): ?>
                <tr><td colspan="8" class="empty">Nenhum veículo encontrado.</td></tr>
            <?php endif; ?>
        </tbody>
    </table>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
