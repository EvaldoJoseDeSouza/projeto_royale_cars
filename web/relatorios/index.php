<?php
/*
|--------------------------------------------------------------------------
| RELATÓRIOS COM FILTROS, IMPRESSÃO E EXPORTAÇÃO CSV
|--------------------------------------------------------------------------
| Tipos: clientes, veículos, aluguéis, manutenções e faturamento.
| - "relatorios" libera os relatórios operacionais.
| - "relatorios_financeiros" libera o faturamento e as colunas de valores.
| O CSV usa ";" e acentos UTF-8, para abrir certinho no Excel em português.
*/

require __DIR__ . '/../includes/bootstrap.php';

exigir_permissao('relatorios', 'relatorios_financeiros');

$verValores = pode('relatorios_financeiros');

$tipos = [];

if (pode('relatorios')) {
    $tipos += [
        'locacoes'    => 'Aluguéis',
        'clientes'    => 'Clientes',
        'veiculos'    => 'Veículos',
        'manutencoes' => 'Manutenções',
    ];
}

if ($verValores) {
    $tipos['faturamento'] = 'Faturamento';
}

$tipo = $_GET['tipo'] ?? array_key_first($tipos);

if (!isset($tipos[$tipo])) {
    acesso_negado();
}

// ---------- Filtros comuns ----------
$f = [
    'de'         => validar_data($_GET['de'] ?? '') ? $_GET['de'] : '',
    'ate'        => validar_data($_GET['ate'] ?? '') ? $_GET['ate'] : '',
    'status'     => (string) ($_GET['status'] ?? ''),
    'cliente_id' => (int) ($_GET['cliente_id'] ?? 0),
    'veiculo_id' => (int) ($_GET['veiculo_id'] ?? 0),
    'usuario_id' => (int) ($_GET['usuario_id'] ?? 0),
];

if ($tipo === 'faturamento' && $f['de'] === '' && $f['ate'] === '' && !isset($_GET['de'])) {
    $f['de'] = date('Y-m-01');
    $f['ate'] = date('Y-m-d');
}

/*
| Cada relatório monta:
|   $colunas = [['rotulo', 'tipo'], ...]   tipo: texto | data | moeda | numero | status
|   $linhas  = [[valor, valor, ...], ...]
|   $resumo  = ['Rótulo' => 'valor já formatado', ...]
*/
$colunas = [];
$linhas = [];
$resumo = [];
$where = ['1 = 1'];
$p = [];

switch ($tipo) {

    case 'clientes':
        if ($f['status'] === 'ativos') {
            $where[] = 'c.arquivado = 0';
        } elseif ($f['status'] === 'arquivados') {
            $where[] = 'c.arquivado = 1';
        } elseif ($f['status'] === 'cnh') {
            $where[] = 'c.cnh_validade <= DATE_ADD(CURDATE(), INTERVAL 30 DAY)';
        }

        if ($f['de']) { $where[] = 'DATE(c.criado_em) >= ?'; $p[] = $f['de']; }
        if ($f['ate']) { $where[] = 'DATE(c.criado_em) <= ?'; $p[] = $f['ate']; }

        $dados = db_todos(
            'SELECT c.*,
                    (SELECT COUNT(*) FROM locacoes l WHERE l.cliente_id = c.id) AS alugueis,
                    (SELECT COALESCE(SUM(valor_total), 0) FROM locacoes l WHERE l.cliente_id = c.id AND l.status = \'Finalizada\') AS gasto
             FROM clientes c WHERE ' . implode(' AND ', $where) . ' ORDER BY c.nome',
            $p
        );

        $colunas = [['Nome', 'texto'], ['CPF', 'texto'], ['Telefone', 'texto'], ['E-mail', 'texto'],
                    ['CNH', 'texto'], ['Validade CNH', 'data'], ['Situação', 'status'], ['Aluguéis', 'numero'], ['Cadastro', 'data']];

        if ($verValores) {
            $colunas[] = ['Total pago', 'moeda'];
        }

        foreach ($dados as $d) {
            $linha = [$d['nome'], formatar_cpf($d['cpf']), formatar_telefone($d['telefone']), $d['email'],
                      $d['cnh'], $d['cnh_validade'], $d['arquivado'] ? 'Arquivado' : 'Ativo', (int) $d['alugueis'], $d['criado_em']];

            if ($verValores) {
                $linha[] = $d['gasto'];
            }

            $linhas[] = $linha;
        }

        $resumo['Clientes'] = count($dados);

        if ($verValores) {
            $resumo['Total pago pelos clientes listados'] = moeda(array_sum(array_column($dados, 'gasto')));
        }
        break;

    case 'veiculos':
        if (in_array($f['status'], ['Disponível', 'Alugado', 'Em manutenção'], true)) {
            $where[] = 'v.status = ? AND v.arquivado = 0';
            $p[] = $f['status'];
        } elseif ($f['status'] === 'arquivados') {
            $where[] = 'v.arquivado = 1';
        } else {
            $where[] = 'v.arquivado = 0';
        }

        $dados = db_todos(
            "SELECT v.*,
                    (SELECT COUNT(*) FROM locacoes l WHERE l.veiculo_id = v.id AND l.status = 'Finalizada') AS alugueis,
                    (SELECT COALESCE(SUM(GREATEST(1, DATEDIFF(l.data_devolucao, l.data_retirada))), 0)
                       FROM locacoes l WHERE l.veiculo_id = v.id AND l.status = 'Finalizada') AS diarias,
                    (SELECT COALESCE(SUM(valor_total), 0) FROM locacoes l WHERE l.veiculo_id = v.id AND l.status = 'Finalizada') AS faturado,
                    (SELECT COALESCE(SUM(custo), 0) FROM manutencoes m WHERE m.veiculo_id = v.id) AS custo
             FROM veiculos v WHERE " . implode(' AND ', $where) . ' ORDER BY v.marca, v.modelo',
            $p
        );

        $colunas = [['Veículo', 'texto'], ['Ano', 'numero'], ['Placa', 'texto'], ['Chassi', 'texto'],
                    ['Diária', 'moeda'], ['Status', 'status'], ['Aluguéis', 'numero'], ['Diárias vendidas', 'numero']];

        if ($verValores) {
            $colunas[] = ['Faturado', 'moeda'];
            $colunas[] = ['Manutenção', 'moeda'];
            $colunas[] = ['Resultado', 'moeda'];
        }

        foreach ($dados as $d) {
            $linha = [nome_veiculo($d), (int) $d['ano'], formatar_placa($d['placa']), $d['chassi'],
                      $d['valor_diaria'], $d['arquivado'] ? 'Arquivado' : $d['status'], (int) $d['alugueis'], (int) $d['diarias']];

            if ($verValores) {
                array_push($linha, $d['faturado'], $d['custo'], $d['faturado'] - $d['custo']);
            }

            $linhas[] = $linha;
        }

        $resumo['Veículos'] = count($dados);

        if ($verValores) {
            $resumo['Faturado'] = moeda(array_sum(array_column($dados, 'faturado')));
            $resumo['Gasto com manutenção'] = moeda(array_sum(array_column($dados, 'custo')));
        }
        break;

    case 'locacoes':
    case 'faturamento':
        $campoData = $tipo === 'faturamento' ? 'l.data_devolucao' : 'l.data_retirada';

        if ($tipo === 'faturamento') {
            $where[] = "l.status = 'Finalizada'";
        } elseif ($f['status'] === 'atrasadas') {
            $where[] = "l.status = 'Em andamento' AND l.data_prevista < CURDATE()";
        } elseif (in_array($f['status'], ['Em andamento', 'Finalizada', 'Cancelada'], true)) {
            $where[] = 'l.status = ?';
            $p[] = $f['status'];
        }

        if ($f['de']) { $where[] = "{$campoData} >= ?"; $p[] = $f['de']; }
        if ($f['ate']) { $where[] = "{$campoData} <= ?"; $p[] = $f['ate']; }
        if ($f['cliente_id']) { $where[] = 'l.cliente_id = ?'; $p[] = $f['cliente_id']; }
        if ($f['veiculo_id']) { $where[] = 'l.veiculo_id = ?'; $p[] = $f['veiculo_id']; }
        if ($f['usuario_id']) { $where[] = 'l.usuario_id = ?'; $p[] = $f['usuario_id']; }

        $dados = db_todos(
            'SELECT l.*, c.nome AS cliente, v.marca, v.modelo, v.placa, u.nome AS funcionario
             FROM locacoes l
             JOIN clientes c ON c.id = l.cliente_id
             JOIN veiculos v ON v.id = l.veiculo_id
             LEFT JOIN usuarios u ON u.id = l.usuario_id
             WHERE ' . implode(' AND ', $where) . "
             ORDER BY {$campoData} DESC, l.id DESC",
            $p
        );

        $colunas = [['#', 'numero'], ['Cliente', 'texto'], ['Veículo', 'texto'], ['Placa', 'texto'],
                    ['Retirada', 'data'], ['Prevista', 'data'], ['Devolução', 'data'],
                    ['Atraso (dias)', 'numero'], ['Status', 'status'], ['Registrado por', 'texto']];

        if ($verValores) {
            $colunas[] = ['Diária', 'moeda'];
            $colunas[] = ['Valor', 'moeda'];
        }

        $porFuncionario = [];

        foreach ($dados as $d) {
            $linha = [(int) $d['id'], $d['cliente'], nome_veiculo($d), formatar_placa($d['placa']),
                      $d['data_retirada'], $d['data_prevista'], $d['data_devolucao'],
                      (int) $d['dias_atraso'], status_locacao($d), $d['funcionario'] ?? '—'];

            if ($verValores) {
                $linha[] = $d['valor_diaria'];
                $linha[] = $d['status'] === 'Cancelada' ? 0 : $d['valor_total'];
            }

            $linhas[] = $linha;

            $nome = $d['funcionario'] ?? '—';
            $porFuncionario[$nome] = ($porFuncionario[$nome] ?? 0) + ($d['status'] === 'Finalizada' ? $d['valor_total'] : 0);
        }

        $resumo['Aluguéis'] = count($dados);

        if ($verValores) {
            $finalizadas = array_filter($dados, fn ($d) => $d['status'] === 'Finalizada');
            $total = array_sum(array_column($finalizadas, 'valor_total'));

            $resumo['Faturado (finalizados)'] = moeda($total);
            $resumo['Diárias de atraso'] = moeda(array_sum(array_column($finalizadas, 'valor_atraso')));
            $resumo['Ticket médio'] = moeda($finalizadas ? $total / count($finalizadas) : 0);

            if ($tipo === 'faturamento') {
                arsort($porFuncionario);

                foreach ($porFuncionario as $nome => $valor) {
                    $resumo['Registrados por ' . $nome] = moeda($valor);
                }
            }
        }
        break;

    case 'manutencoes':
        if (in_array($f['status'], ['Em andamento', 'Concluída'], true)) {
            $where[] = 'm.status = ?';
            $p[] = $f['status'];
        }

        if ($f['de']) { $where[] = 'm.data_entrada >= ?'; $p[] = $f['de']; }
        if ($f['ate']) { $where[] = 'm.data_entrada <= ?'; $p[] = $f['ate']; }
        if ($f['veiculo_id']) { $where[] = 'm.veiculo_id = ?'; $p[] = $f['veiculo_id']; }
        if ($f['usuario_id']) { $where[] = 'm.usuario_id = ?'; $p[] = $f['usuario_id']; }

        $dados = db_todos(
            'SELECT m.*, v.marca, v.modelo, v.placa, u.nome AS funcionario,
                    DATEDIFF(COALESCE(m.data_liberacao, CURDATE()), m.data_entrada) AS dias
             FROM manutencoes m
             JOIN veiculos v ON v.id = m.veiculo_id
             LEFT JOIN usuarios u ON u.id = m.usuario_id
             WHERE ' . implode(' AND ', $where) . ' ORDER BY m.data_entrada DESC',
            $p
        );

        $colunas = [['Veículo', 'texto'], ['Placa', 'texto'], ['Defeito', 'texto'], ['Serviço', 'texto'], ['Oficina', 'texto'],
                    ['Entrada', 'data'], ['Liberação', 'data'], ['Dias parado', 'numero'], ['Status', 'status'], ['Aberto por', 'texto']];

        if ($verValores) {
            $colunas[] = ['Custo', 'moeda'];
        }

        foreach ($dados as $d) {
            $linha = [nome_veiculo($d), formatar_placa($d['placa']), $d['defeito'], $d['servico_realizado'] ?? '', $d['oficina'] ?? '',
                      $d['data_entrada'], $d['data_liberacao'], (int) $d['dias'], $d['status'], $d['funcionario'] ?? '—'];

            if ($verValores) {
                $linha[] = $d['custo'];
            }

            $linhas[] = $linha;
        }

        $resumo['Manutenções'] = count($dados);
        $resumo['Dias parados (soma)'] = array_sum(array_column($dados, 'dias'));

        if ($verValores) {
            $resumo['Custo total'] = moeda(array_sum(array_column($dados, 'custo')));
        }
        break;
}


/* ---------- Exportar CSV ---------- */

if (($_GET['formato'] ?? '') === 'csv') {
    registrar_log('relatorios', 'exportar', null, "Exportou o relatório de {$tipos[$tipo]} em CSV (" . count($linhas) . ' linhas).');

    header('Content-Type: text/csv; charset=UTF-8');
    header('Content-Disposition: attachment; filename="royale-cars-' . $tipo . '-' . date('Y-m-d') . '.csv"');

    $saida = fopen('php://output', 'w');
    fwrite($saida, "\xEF\xBB\xBF"); // Faz o Excel reconhecer os acentos

    fputcsv($saida, array_column($colunas, 0), ';');

    foreach ($linhas as $linha) {
        $csv = [];

        foreach ($linha as $i => $valor) {
            $csv[] = match ($colunas[$i][1]) {
                'moeda' => $valor === null ? '' : number_format((float) $valor, 2, ',', ''),
                'data'  => $valor ? date('d/m/Y', strtotime($valor)) : '',
                default => (string) $valor,
            };
        }

        // Evita "injeção de fórmula" no Excel (célula começando com = + - @)
        $csv = array_map(fn ($c) => preg_match('/^[=+\-@]/', $c) && !is_numeric(str_replace(',', '.', $c)) ? "'" . $c : $c, $csv);

        fputcsv($saida, $csv, ';');
    }

    fclose($saida);
    exit;
}


/* ---------- Tela ---------- */

$clientes = db_todos('SELECT id, nome FROM clientes ORDER BY nome');
$veiculos = db_todos('SELECT id, marca, modelo, placa FROM veiculos ORDER BY marca, modelo');
$usuarios = db_todos('SELECT id, nome FROM usuarios ORDER BY nome');

$opcoesStatus = [
    'clientes'    => ['' => 'Todos', 'ativos' => 'Ativos', 'arquivados' => 'Arquivados', 'cnh' => 'CNH vencida/vencendo'],
    'veiculos'    => ['' => 'Na frota', 'Disponível' => 'Disponíveis', 'Alugado' => 'Alugados', 'Em manutenção' => 'Em manutenção', 'arquivados' => 'Arquivados'],
    'locacoes'    => ['' => 'Todos', 'Em andamento' => 'Em andamento', 'atrasadas' => 'Atrasados', 'Finalizada' => 'Finalizados', 'Cancelada' => 'Cancelados'],
    'manutencoes' => ['' => 'Todas', 'Em andamento' => 'Na oficina', 'Concluída' => 'Concluídas'],
    'faturamento' => [],
];

$rotuloPeriodo = [
    'clientes'    => 'Cadastrados',
    'locacoes'    => 'Retirada',
    'faturamento' => 'Devolução',
    'manutencoes' => 'Entrada',
    'veiculos'    => '',
];

$parametrosAtuais = array_filter(['tipo' => $tipo] + $f);

$titulo = 'Relatórios';
$subtitulo = 'Relatório de ' . mb_strtolower($tipos[$tipo]);
$menu = 'relatorios';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="so-impressao" style="margin-bottom: 12px;">
    <h2>ROYALE CARS — Relatório de <?= e(mb_strtolower($tipos[$tipo])) ?></h2>
    <p>
        Emitido em <?= date('d/m/Y H:i') ?> por <?= e(usuario_logado()['nome']) ?>
        <?php if ($f['de'] || $f['ate']): ?>
            · Período: <?= $f['de'] ? data_br($f['de']) : 'início' ?> a <?= $f['ate'] ? data_br($f['ate']) : 'hoje' ?>
        <?php endif; ?>
    </p>
</div>

<nav class="abas">
    <?php foreach ($tipos as $chave => $nome): ?>
        <a href="<?= e(url('relatorios/index.php?tipo=' . $chave)) ?>" class="<?= $tipo === $chave ? 'ativa' : '' ?>"><?= e($nome) ?></a>
    <?php endforeach; ?>
</nav>

<form method="GET" class="filtros">
    <input type="hidden" name="tipo" value="<?= e($tipo) ?>">

    <?php if ($rotuloPeriodo[$tipo]): ?>
        <div class="filtro">
            <label for="de"><?= e($rotuloPeriodo[$tipo]) ?> de</label>
            <input type="date" id="de" name="de" value="<?= e($f['de']) ?>">
        </div>
        <div class="filtro">
            <label for="ate">até</label>
            <input type="date" id="ate" name="ate" value="<?= e($f['ate']) ?>">
        </div>
    <?php endif; ?>

    <?php if ($opcoesStatus[$tipo]): ?>
        <div class="filtro">
            <label for="status">Situação</label>
            <select id="status" name="status">
                <?php foreach ($opcoesStatus[$tipo] as $valor => $texto): ?>
                    <option value="<?= e($valor) ?>" <?= $f['status'] === (string) $valor ? 'selected' : '' ?>><?= e($texto) ?></option>
                <?php endforeach; ?>
            </select>
        </div>
    <?php endif; ?>

    <?php if (in_array($tipo, ['locacoes', 'faturamento'], true)): ?>
        <div class="filtro">
            <label for="cliente_id">Cliente</label>
            <select id="cliente_id" name="cliente_id">
                <option value="">Todos</option>
                <?php foreach ($clientes as $c): ?>
                    <option value="<?= $c['id'] ?>" <?= $f['cliente_id'] === (int) $c['id'] ? 'selected' : '' ?>><?= e($c['nome']) ?></option>
                <?php endforeach; ?>
            </select>
        </div>
    <?php endif; ?>

    <?php if (in_array($tipo, ['locacoes', 'faturamento', 'manutencoes'], true)): ?>
        <div class="filtro">
            <label for="veiculo_id">Veículo</label>
            <select id="veiculo_id" name="veiculo_id">
                <option value="">Todos</option>
                <?php foreach ($veiculos as $v): ?>
                    <option value="<?= $v['id'] ?>" <?= $f['veiculo_id'] === (int) $v['id'] ? 'selected' : '' ?>><?= e(nome_veiculo($v)) ?> (<?= e(formatar_placa($v['placa'])) ?>)</option>
                <?php endforeach; ?>
            </select>
        </div>

        <div class="filtro">
            <label for="usuario_id">Funcionário</label>
            <select id="usuario_id" name="usuario_id">
                <option value="">Todos</option>
                <?php foreach ($usuarios as $u): ?>
                    <option value="<?= $u['id'] ?>" <?= $f['usuario_id'] === (int) $u['id'] ? 'selected' : '' ?>><?= e($u['nome']) ?></option>
                <?php endforeach; ?>
            </select>
        </div>
    <?php endif; ?>

    <button type="submit" class="btn-primary">Filtrar</button>
</form>

<div class="page-header">
    <div class="legenda">
        <?php foreach ($resumo as $rotulo => $valor): ?>
            <span><?= e($rotulo) ?>: <strong><?= e($valor) ?></strong></span>
        <?php endforeach; ?>
    </div>

    <div class="acoes-topo nao-imprimir">
        <button type="button" class="btn-secondary" onclick="window.print()">Imprimir</button>
        <a href="<?= e(url('relatorios/index.php?' . http_build_query($parametrosAtuais + ['formato' => 'csv']))) ?>" class="btn-primary">Exportar CSV</a>
    </div>
</div>

<div class="table-container">
    <table class="tabela-compacta">
        <thead>
            <tr>
                <?php foreach ($colunas as [$rotulo, $tipoColuna]): ?>
                    <th class="<?= in_array($tipoColuna, ['moeda', 'numero'], true) ? 'numero' : '' ?>"><?= e($rotulo) ?></th>
                <?php endforeach; ?>
            </tr>
        </thead>
        <tbody>
            <?php foreach ($linhas as $linha): ?>
                <tr>
                    <?php foreach ($linha as $i => $valor): ?>
                        <?php $tipoColuna = $colunas[$i][1]; ?>
                        <td class="<?= in_array($tipoColuna, ['moeda', 'numero'], true) ? 'numero' : (in_array($tipoColuna, ['data', 'status'], true) || $colunas[$i][0] === 'Placa' ? 'nowrap' : '') ?>">
                            <?php if ($tipoColuna === 'moeda'): ?>
                                <?= $valor === null ? '—' : moeda($valor) ?>
                            <?php elseif ($tipoColuna === 'data'): ?>
                                <?= data_br($valor) ?>
                            <?php elseif ($tipoColuna === 'status'): ?>
                                <?= badge_status((string) $valor) ?>
                            <?php else: ?>
                                <?= e($valor) ?>
                            <?php endif; ?>
                        </td>
                    <?php endforeach; ?>
                </tr>
            <?php endforeach; ?>

            <?php if (!$linhas): ?>
                <tr><td colspan="<?= count($colunas) ?>" class="empty">Nenhum registro encontrado com esses filtros.</td></tr>
            <?php endif; ?>
        </tbody>
    </table>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
