<?php
/*
|--------------------------------------------------------------------------
| DADOS MENSAIS E GRÁFICO DE BARRAS
|--------------------------------------------------------------------------
| O gráfico é feito só com HTML e CSS (sem biblioteca externa), então
| funciona mesmo sem internet na hora da apresentação.
|
| O faturamento entra no mês em que o carro foi DEVOLVIDO (quando o valor
| final é conhecido). O custo de manutenção entra no mês da liberação.
*/

function dados_mensais(int $meses = 6): array
{
    $inicio = date('Y-m-01', strtotime('-' . ($meses - 1) . ' months', strtotime(date('Y-m-01'))));
    $dados = [];

    for ($i = 0; $i < $meses; $i++) {
        $chave = date('Y-m', strtotime("+{$i} months", strtotime($inicio)));
        $dados[$chave] = ['faturamento' => 0.0, 'alugueis' => 0, 'manutencao' => 0.0];
    }

    $linhas = db_todos(
        "SELECT DATE_FORMAT(data_devolucao, '%Y-%m') AS mes,
                SUM(valor_total) AS faturamento, COUNT(*) AS alugueis
         FROM locacoes
         WHERE status = 'Finalizada' AND data_devolucao >= ?
         GROUP BY mes",
        [$inicio]
    );

    foreach ($linhas as $linha) {
        if (isset($dados[$linha['mes']])) {
            $dados[$linha['mes']]['faturamento'] = (float) $linha['faturamento'];
            $dados[$linha['mes']]['alugueis'] = (int) $linha['alugueis'];
        }
    }

    $custos = db_todos(
        "SELECT DATE_FORMAT(data_liberacao, '%Y-%m') AS mes, SUM(custo) AS total
         FROM manutencoes
         WHERE status = 'Concluída' AND data_liberacao >= ?
         GROUP BY mes",
        [$inicio]
    );

    foreach ($custos as $linha) {
        if (isset($dados[$linha['mes']])) {
            $dados[$linha['mes']]['manutencao'] = (float) $linha['total'];
        }
    }

    return $dados;
}

function rotulo_mes(string $anoMes): string
{
    [$ano, $mes] = explode('-', $anoMes);

    return mes_abreviado((int) $mes) . '/' . substr($ano, 2);
}

/** Valor curto para cima da barra: 12.500 → "12,5 mil" */
function valor_curto(float $valor): string
{
    if ($valor >= 1000000) {
        return number_format($valor / 1000000, 1, ',', '.') . ' mi';
    }

    if ($valor >= 1000) {
        return number_format($valor / 1000, 1, ',', '.') . ' mil';
    }

    return number_format($valor, 0, ',', '.');
}

/**
 * Desenha o gráfico de barras.
 * $valores: ['2026-05' => 1234.5, ...]   $dinheiro: formata como R$
 */
function grafico_barras(array $valores, bool $dinheiro = true): string
{
    $maximo = max(1, max($valores ?: [0]));
    $mesAtual = date('Y-m');

    $colunas = '';
    $rotulos = '';

    foreach ($valores as $mes => $valor) {
        $altura = $valor > 0 ? max(2, round($valor / $maximo * 100, 1)) : 0;
        $textoCompleto = rotulo_mes($mes) . ': ' . ($dinheiro ? moeda($valor) : $valor);
        $classe = $mes === $mesAtual ? ' atual' : '';

        $colunas .= '<div class="grafico-coluna' . $classe . '" title="' . e($textoCompleto) . '">'
            . '<span class="grafico-valor">' . e($dinheiro ? valor_curto($valor) : (string) $valor) . '</span>'
            . '<div class="grafico-barra" style="height: ' . $altura . '%"></div>'
            . '</div>';

        $rotulos .= '<span>' . e(rotulo_mes($mes)) . '</span>';
    }

    return '<div class="grafico" role="img" aria-label="Gráfico de barras por mês">' . $colunas . '</div>'
         . '<div class="grafico-rotulos">' . $rotulos . '</div>';
}

/** Situação da frota agora (só veículos não arquivados). */
function situacao_frota(): array
{
    $frota = ['Disponível' => 0, 'Alugado' => 0, 'Em manutenção' => 0];

    foreach (db_todos('SELECT status, COUNT(*) AS total FROM veiculos WHERE arquivado = 0 GROUP BY status') as $linha) {
        $frota[$linha['status']] = (int) $linha['total'];
    }

    return $frota;
}

function barra_frota(array $frota): string
{
    $total = max(1, array_sum($frota));
    $cores = ['Disponível' => 'cor-disponivel', 'Alugado' => 'cor-alugado', 'Em manutenção' => 'cor-manutencao'];

    $barra = '<div class="barra-frota">';
    $legenda = '<div class="legenda">';

    foreach ($frota as $status => $quantidade) {
        $pct = round($quantidade / $total * 100, 1);

        if ($quantidade > 0) {
            $barra .= '<div class="' . $cores[$status] . '" style="width: ' . $pct . '%" title="' . e("{$status}: {$quantidade}") . '"></div>';
        }

        $legenda .= '<span><i class="' . $cores[$status] . '"></i>' . e($status) . ': <strong>' . $quantidade . '</strong></span>';
    }

    return $barra . '</div>' . $legenda . '</div>';
}
