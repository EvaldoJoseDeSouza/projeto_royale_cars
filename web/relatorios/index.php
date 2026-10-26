<?php
/*
| RELATÓRIOS COM FILTROS, IMPRESSÃO E EXPORTAÇÃO CSV
*/

require __DIR__ . '/../includes/bootstrap.php';

exigir_permissao('relatorios', 'relatorios_financeiros');

$verValores = pode('relatorios_financeiros');

$tipos = [];

if (pode('relatorios')) {
    $tipos += [
        'locacoes'    => 'Locações',
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

$usuarioId = (string) ($_GET['usuario_id'] ?? '');

$f = [
    'de'         => validar_data($_GET['de'] ?? '') ? $_GET['de'] : '',
    'ate'        => validar_data($_GET['ate'] ?? '') ? $_GET['ate'] : '',
    'status'     => (string) ($_GET['status'] ?? ''),
    'cliente_id' => (int) ($_GET['cliente_id'] ?? 0),
    'veiculo_id' => (int) ($_GET['veiculo_id'] ?? 0),
    'usuario_id' => preg_match('/^[0-9a-f-]{36}$/', $usuarioId) ? $usuarioId : '',
];

if ($tipo === 'faturamento' && $f['de'] === '' && $f['ate'] === '' && !isset($_GET['de'])) {
    $f['de'] = date('Y-m-01');
    $f['ate'] = date('Y-m-d');
}
function filtro_periodo(string $coluna, string $de, string $ate, bool $comHora = false): array
{
    $partes = [];

    if ($de) {
        $partes[] = "{$coluna}.gte.{$de}";
    }

    if ($ate) {
        $partes[] = $comHora ? "{$coluna}.lt." . date('Y-m-d', strtotime($ate . ' +1 day')) : "{$coluna}.lte.{$ate}";
    }

    return $partes ? ['and' => '(' . implode(',', $partes) . ')'] : [];
}

function somar_por(array $linhas, string $grupo, ?string $campo = null): array
{
    $totais = [];

    foreach ($linhas as $l) {
        $totais[$l[$grupo]] = ($totais[$l[$grupo]] ?? 0) + ($campo === null ? 1 : (float) $l[$campo]);
    }

    return $totais;
}

$colunas = [];
$linhas = [];
$resumo = [];

switch ($tipo) {

    case 'clientes':
        $filtros = ['select' => '*', 'order' => 'nome.asc'] + filtro_periodo('criado_em', $f['de'], $f['ate'], true);

        if ($f['status'] === 'ativos') {
            $filtros['arquivado'] = 'eq.false';
        } elseif ($f['status'] === 'arquivados') {
            $filtros['arquivado'] = 'eq.true';
        } elseif ($f['status'] === 'cnh') {
            $filtros['cnh_validade'] = 'lte.' . date('Y-m-d', strtotime('+' . DIAS_AVISO_CNH . ' days'));
        }

        $dados = sb_select('clientes', $filtros);

        $locacoes = sb_select('locacoes', ['select' => 'cliente_id,status,valor_total']);
        $alugueis = somar_por($locacoes, 'cliente_id');
        $gasto = somar_por(array_filter($locacoes, fn ($l) => $l['status'] === 'Finalizada'), 'cliente_id', 'valor_total');

        $colunas = [['Nome', 'texto'], ['CPF', 'texto'], ['Telefone', 'texto'], ['E-mail', 'texto'],
                    ['CNH', 'texto'], ['Validade CNH', 'data'], ['Situação', 'status'], ['Aluguéis', 'numero'], ['Cadastro', 'data']];

        if ($verValores) {
            $colunas[] = ['Total pago', 'moeda'];
        }

        $totalPago = 0;

        foreach ($dados as $d) {
            $linha = [$d['nome'], formatar_cpf($d['cpf']), formatar_telefone($d['telefone']), $d['email'],
                      $d['cnh'], $d['cnh_validade'], $d['arquivado'] ? 'Arquivado' : 'Ativo',
                      (int) ($alugueis[$d['id']] ?? 0), $d['criado_em']];

            if ($verValores) {
                $linha[] = $gasto[$d['id']] ?? 0;
                $totalPago += $gasto[$d['id']] ?? 0;
            }

            $linhas[] = $linha;
        }

        $resumo['Clientes'] = count($dados);

        if ($verValores) {
            $resumo['Total pago pelos clientes listados'] = moeda($totalPago);
        }
        break;

    case 'veiculos':
        $filtros = ['select' => '*', 'order' => 'marca.asc,modelo.asc'];

        if (in_array($f['status'], ['Disponível', 'Alugado', 'Em manutenção'], true)) {
            $filtros['status'] = 'eq.' . $f['status'];
            $filtros['arquivado'] = 'eq.false';
        } elseif ($f['status'] === 'arquivados') {
            $filtros['arquivado'] = 'eq.true';
        } else {
            $filtros['arquivado'] = 'eq.false';
        }

        $dados = sb_select('veiculos', $filtros);

        $finalizadas = sb_select('locacoes', ['select' => 'veiculo_id,data_retirada,data_devolucao,valor_total', 'status' => 'eq.Finalizada']);
        $alugueis = somar_por($finalizadas, 'veiculo_id');
        $faturado = somar_por($finalizadas, 'veiculo_id', 'valor_total');
        $diarias = [];

        foreach ($finalizadas as $l) {
            $diarias[$l['veiculo_id']] = ($diarias[$l['veiculo_id']] ?? 0) + max(1, dias_entre($l['data_retirada'], $l['data_devolucao']));
        }

        $custo = somar_por(sb_select('manutencoes', ['select' => 'veiculo_id,custo', 'custo' => 'not.is.null']), 'veiculo_id', 'custo');

        $colunas = [['Veículo', 'texto'], ['Ano', 'numero'], ['Placa', 'texto'], ['Chassi', 'texto'],
                    ['Diária', 'moeda'], ['Km', 'numero'], ['Status', 'status'], ['Aluguéis', 'numero'], ['Diárias vendidas', 'numero']];

        if ($verValores) {
            $colunas[] = ['Faturado', 'moeda'];
            $colunas[] = ['Manutenção', 'moeda'];
            $colunas[] = ['Resultado', 'moeda'];
        }

        $somaFaturado = 0;
        $somaCusto = 0;

        foreach ($dados as $d) {
            $linha = [nome_veiculo($d), (int) $d['ano'], formatar_placa($d['placa']), $d['chassi'],
                      $d['valor_diaria'], (int) $d['quilometragem'], $d['arquivado'] ? 'Arquivado' : $d['status'],
                      (int) ($alugueis[$d['id']] ?? 0), (int) ($diarias[$d['id']] ?? 0)];

            if ($verValores) {
                $fat = $faturado[$d['id']] ?? 0;
                $cus = $custo[$d['id']] ?? 0;
                array_push($linha, $fat, $cus, $fat - $cus);
                $somaFaturado += $fat;
                $somaCusto += $cus;
            }

            $linhas[] = $linha;
        }

        $resumo['Veículos'] = count($dados);

        if ($verValores) {
            $resumo['Faturado'] = moeda($somaFaturado);
            $resumo['Gasto com manutenção'] = moeda($somaCusto);
        }
        break;

    case 'locacoes':
    case 'faturamento':
        $campoData = $tipo === 'faturamento' ? 'data_devolucao' : 'data_retirada';
        $filtros = [
            'select' => 'id,cliente_nome,marca,modelo,placa,data_retirada,data_prevista,data_devolucao,dias_atraso,'
                      . 'dias_atraso_atual,valor_atraso,taxas_extras,valor_diaria,valor_total,status,status_exibicao,registrado_por',
            'order'  => "{$campoData}.desc,id.desc",
        ] + filtro_periodo($campoData, $f['de'], $f['ate']);

        if ($tipo === 'faturamento') {
            $filtros['status'] = 'eq.Finalizada';
        } elseif ($f['status'] === 'atrasadas') {
            $filtros['status_exibicao'] = 'eq.Atrasada';
        } elseif (in_array($f['status'], ['Em andamento', 'Finalizada', 'Cancelada'], true)) {
            $filtros['status'] = 'eq.' . $f['status'];
        }

        if ($f['cliente_id']) { $filtros['cliente_id'] = 'eq.' . $f['cliente_id']; }
        if ($f['veiculo_id']) { $filtros['veiculo_id'] = 'eq.' . $f['veiculo_id']; }
        if ($f['usuario_id']) { $filtros['usuario_id'] = 'eq.' . $f['usuario_id']; }

        $dados = sb_select('vw_locacoes', $filtros);

        $colunas = [['#', 'numero'], ['Cliente', 'texto'], ['Veículo', 'texto'], ['Placa', 'texto'],
                    ['Retirada', 'data'], ['Prevista', 'data'], ['Devolução', 'data'],
                    ['Atraso (dias)', 'numero'], ['Status', 'status'], ['Registrado por', 'texto']];

        if ($verValores) {
            $colunas[] = ['Diária', 'moeda'];
            $colunas[] = ['Taxas extras', 'moeda'];
            $colunas[] = ['Valor', 'moeda'];
        }

        $porFuncionario = [];

        foreach ($dados as $d) {
            $atraso = $d['status'] === 'Em andamento' ? $d['dias_atraso_atual'] : $d['dias_atraso'];

            $linha = [(int) $d['id'], $d['cliente_nome'], nome_veiculo($d), formatar_placa($d['placa']),
                      $d['data_retirada'], $d['data_prevista'], $d['data_devolucao'],
                      (int) $atraso, $d['status_exibicao'], $d['registrado_por'] ?? '—'];

            if ($verValores) {
                $linha[] = $d['valor_diaria'];
                $linha[] = $d['taxas_extras'];
                $linha[] = $d['status'] === 'Cancelada' ? 0 : $d['valor_total'];
            }

            $linhas[] = $linha;

            $nome = $d['registrado_por'] ?? '—';
            $porFuncionario[$nome] = ($porFuncionario[$nome] ?? 0) + ($d['status'] === 'Finalizada' ? $d['valor_total'] : 0);
        }

        $resumo['Aluguéis'] = count($dados);

        if ($verValores) {
            $finalizadas = array_filter($dados, fn ($d) => $d['status'] === 'Finalizada');
            $total = array_sum(array_column($finalizadas, 'valor_total'));

            $resumo['Faturado (finalizados)'] = moeda($total);
            $resumo['Diárias de atraso'] = moeda(array_sum(array_column($finalizadas, 'valor_atraso')));
            $resumo['Taxas extras'] = moeda(array_sum(array_column($finalizadas, 'taxas_extras')));
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
        $filtros = [
            'select' => '*,veiculos(marca,modelo,placa),abriu:perfis!manutencoes_usuario_id_fkey(nome)',
            'order'  => 'data_entrada.desc,id.desc',
        ] + filtro_periodo('data_entrada', $f['de'], $f['ate']);

        if (in_array($f['status'], ['Em andamento', 'Concluída'], true)) {
            $filtros['status'] = 'eq.' . $f['status'];
        }

        if ($f['veiculo_id']) { $filtros['veiculo_id'] = 'eq.' . $f['veiculo_id']; }
        if ($f['usuario_id']) { $filtros['usuario_id'] = 'eq.' . $f['usuario_id']; }

        $dados = sb_select('manutencoes', $filtros);

        $colunas = [['Veículo', 'texto'], ['Placa', 'texto'], ['Defeito', 'texto'], ['Serviço', 'texto'], ['Oficina', 'texto'],
                    ['Entrada', 'data'], ['Liberação', 'data'], ['Dias parado', 'numero'], ['Status', 'status'], ['Aberto por', 'texto']];

        if ($verValores) {
            $colunas[] = ['Custo', 'moeda'];
        }

        $somaDias = 0;

        foreach ($dados as $d) {
            $v = $d['veiculos'] ?? [];
            $dias = dias_entre($d['data_entrada'], $d['data_liberacao'] ?? date('Y-m-d'));
            $somaDias += $dias;

            $linha = [nome_veiculo($v), formatar_placa($v['placa'] ?? ''), $d['defeito'], $d['servico_realizado'] ?? '', $d['oficina'] ?? '',
                      $d['data_entrada'], $d['data_liberacao'], $dias, $d['status'], $d['abriu']['nome'] ?? '—'];

            if ($verValores) {
                $linha[] = $d['custo'];
            }

            $linhas[] = $linha;
        }

        $resumo['Manutenções'] = count($dados);
        $resumo['Dias parados (soma)'] = $somaDias;

        if ($verValores) {
            $resumo['Custo total'] = moeda(array_sum(array_column($dados, 'custo')));
        }
        break;
}


/* ---------- Exportar CSV ---------- */

if (($_GET['formato'] ?? '') === 'csv') {
    header('Content-Type: text/csv; charset=UTF-8');
    header('Content-Disposition: attachment; filename="royale-cars-' . $tipo . '-' . date('Y-m-d') . '.csv"');

    $saida = fopen('php://output', 'w');
    fwrite($saida, "\xEF\xBB\xBF"); 

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

$clientes = sb_select('clientes', ['select' => 'id,nome', 'order' => 'nome.asc']);
$veiculos = sb_select('veiculos', ['select' => 'id,marca,modelo,placa', 'order' => 'marca.asc,modelo.asc']);
$usuarios = sb_select('perfis', ['select' => 'id,nome', 'order' => 'nome.asc']);

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
                    <option value="<?= e($u['id']) ?>" <?= $f['usuario_id'] === $u['id'] ? 'selected' : '' ?>><?= e($u['nome']) ?></option>
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
