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

// Uma pergunta ao banco traz a frota (com a busca). As abas e o filtro
// por status são feitos aqui mesmo, sem voltar ao banco.
$frota = listar_veiculos(false, $busca);

$contagem = ['' => count($frota)] + array_fill_keys(STATUS_VEICULO, 0);

foreach ($frota as $v) {
    $contagem[$v['status']]++;
}

$veiculos = $status === '' ? $frota : array_values(array_filter($frota, fn ($v) => $v['status'] === $status));

// Ordem da tela: disponíveis primeiro, depois alugados, depois na oficina
// (dentro de cada grupo, a ordem de marca e modelo que veio do banco)
usort($veiculos, fn ($a, $b) => array_search($a['status'], STATUS_VEICULO) <=> array_search($b['status'], STATUS_VEICULO));

$voltas = devolucoes_previstas();
$totalArquivados = sb_contar('veiculos', ['arquivado' => 'eq.true']);

$titulo = 'Frota';
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
                <th class="numero">Km</th>
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
                    <td class="numero nowrap"><?= number_format((int) $veiculo['quilometragem'], 0, ',', '.') ?></td>
                    <td class="numero"><?= moeda($veiculo['valor_diaria']) ?></td>
                    <td>
                        <?= badge_status($veiculo['status']) ?>
                        <?php if ($volta = $voltas[$veiculo['id']] ?? null): ?>
                            <br><small class="<?= $volta < date('Y-m-d') ? 'texto-vermelho' : 'texto-fraco' ?>">
                                volta <?= data_br($volta) ?>
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
                <tr><td colspan="9" class="empty">Nenhum veículo encontrado.</td></tr>
            <?php endif; ?>
        </tbody>
    </table>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
