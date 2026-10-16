<?php
/*
|--------------------------------------------------------------------------
| ALUGUÉIS
|--------------------------------------------------------------------------
| Abas: em andamento, atrasados, finalizados, cancelados e todos.
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/locacoes.php';

exigir_permissao('locacoes_ver');

$aba = $_GET['aba'] ?? 'andamento';

if (!isset(ABAS_LOCACAO[$aba])) {
    $aba = 'andamento';
}

$busca = trim($_GET['busca'] ?? '');
$de = $_GET['de'] ?? '';
$ate = $_GET['ate'] ?? '';

// A visão vw_locacoes já junta aluguel + cliente + veículo
$filtro = filtro_locacoes($busca, $de, $ate);

$contagem = [];

foreach (ABAS_LOCACAO as $chave => $info) {
    $contagem[$chave] = sb_contar('vw_locacoes', $filtro + $info['filtro']);
}

[$limite, $offset, $pagina, $totalPaginas] = paginar($contagem[$aba]);

$locacoes = sb_select('vw_locacoes', $filtro + ABAS_LOCACAO[$aba]['filtro'] + [
    'select' => 'id,cliente_nome,cliente_telefone,marca,modelo,placa,data_retirada,data_prevista,data_devolucao,'
              . 'valor_previsto,valor_total,status,status_exibicao,dias_atraso_atual',
    // Em andamento e atrasados: quem vence primeiro aparece primeiro
    'order'  => in_array($aba, ['andamento', 'atrasadas'], true) ? 'data_prevista.asc,id.asc' : 'id.desc',
    'limit'  => $limite,
    'offset' => $offset,
]);

$titulo = 'Aluguéis';
$subtitulo = 'Retiradas, devoluções e atrasos';
$menu = 'locacoes';
require RAIZ . '/includes/cabecalho.php';

$filtrosAtuais = array_filter(['busca' => $busca, 'de' => $de, 'ate' => $ate]);
?>

<div class="page-header">
    <div>
        <h2>Aluguéis</h2>
        <p>Ao registrar um aluguel o carro fica indisponível; na devolução ele é liberado.</p>
    </div>

    <?php if (pode('locacoes_gerenciar')): ?>
        <a href="<?= e(url('locacoes/cadastrar.php')) ?>" class="btn-primary">+ Novo aluguel</a>
    <?php endif; ?>
</div>

<form method="GET" class="filtros">
    <input type="hidden" name="aba" value="<?= e($aba) ?>">
    <div class="filtro largo">
        <label for="busca">Buscar</label>
        <input type="text" id="busca" name="busca" value="<?= e($busca) ?>" placeholder="Cliente, veículo, placa ou nº do aluguel">
    </div>
    <div class="filtro">
        <label for="de">Retirada de</label>
        <input type="date" id="de" name="de" value="<?= e($de) ?>">
    </div>
    <div class="filtro">
        <label for="ate">até</label>
        <input type="date" id="ate" name="ate" value="<?= e($ate) ?>">
    </div>
    <button type="submit" class="btn-primary">Filtrar</button>
    <?php if ($filtrosAtuais): ?>
        <a href="<?= e(url('locacoes/index.php?aba=' . $aba)) ?>" class="btn-secondary">Limpar</a>
    <?php endif; ?>
</form>

<nav class="abas">
    <?php foreach (ABAS_LOCACAO as $chave => $info): ?>
        <a href="<?= e(url('locacoes/index.php?' . http_build_query(['aba' => $chave] + $filtrosAtuais))) ?>"
           class="<?= $aba === $chave ? 'ativa' : '' ?>">
            <?= e($info['texto']) ?> <b><?= $contagem[$chave] ?></b>
        </a>
    <?php endforeach; ?>
</nav>

<div class="table-container">
    <table>
        <thead>
            <tr>
                <th>#</th>
                <th>Cliente</th>
                <th>Veículo</th>
                <th>Retirada</th>
                <th>Devolução</th>
                <th class="numero">Valor</th>
                <th>Status</th>
                <th>Ações</th>
            </tr>
        </thead>
        <tbody>
            <?php foreach ($locacoes as $l): ?>
                <?php $status = $l['status_exibicao']; ?>
                <tr class="<?= $status === 'Atrasada' ? 'linha-alerta' : '' ?>">
                    <td>#<?= $l['id'] ?></td>
                    <td>
                        <strong><?= e($l['cliente_nome']) ?></strong><br>
                        <span class="texto-fraco"><?= e(formatar_telefone($l['cliente_telefone'])) ?></span>
                    </td>
                    <td>
                        <?= e(nome_veiculo($l)) ?><br>
                        <span class="texto-fraco nowrap"><?= e(formatar_placa($l['placa'])) ?></span>
                    </td>
                    <td><?= data_br($l['data_retirada']) ?></td>
                    <td>
                        <?php if ($l['data_devolucao']): ?>
                            <?= data_br($l['data_devolucao']) ?>
                        <?php else: ?>
                            <span class="<?= $status === 'Atrasada' ? 'texto-vermelho' : '' ?>">prevista <?= data_br($l['data_prevista']) ?></span>
                            <?php if ($status === 'Atrasada'): ?>
                                <br><small class="texto-vermelho"><?= (int) $l['dias_atraso_atual'] ?> dia(s) de atraso</small>
                            <?php endif; ?>
                        <?php endif; ?>
                    </td>
                    <td class="numero">
                        <?= moeda($l['status'] === 'Cancelada' ? $l['valor_previsto'] : $l['valor_total']) ?>
                        <?php if ($l['status'] === 'Em andamento'): ?><br><small class="texto-fraco">previsto</small><?php endif; ?>
                    </td>
                    <td><?= badge_status($status) ?></td>
                    <td>
                        <a href="<?= e(url('locacoes/ver.php?id=' . $l['id'])) ?>" class="btn-small btn-claro">Ver</a>
                        <?php if ($l['status'] === 'Em andamento' && pode('locacoes_gerenciar')): ?>
                            <a href="<?= e(url('locacoes/devolver.php?id=' . $l['id'])) ?>" class="btn-small btn-success">Devolução</a>
                        <?php endif; ?>
                    </td>
                </tr>
            <?php endforeach; ?>

            <?php if (!$locacoes): ?>
                <tr><td colspan="8" class="empty">Nenhum aluguel nesta lista.</td></tr>
            <?php endif; ?>
        </tbody>
    </table>
</div>

<?= links_paginacao($pagina, $totalPaginas) ?>

<?php require RAIZ . '/includes/rodape.php'; ?>
