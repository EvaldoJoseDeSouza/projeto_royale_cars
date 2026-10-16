<?php
/*
|--------------------------------------------------------------------------
| DADOS MENSAIS E GRÁFICO DE BARRAS
|--------------------------------------------------------------------------
| O gráfico é feito só com HTML e CSS (sem biblioteca externa), então
| funciona mesmo sem internet na hora da apresentação.
|
| Os números vêm das visões do banco, as mesmas do desktop:
|   vw_faturamento_mensal → faturamento, aluguéis e manutenção, mês a mês
|                           (só aparece para quem tem a permissão financeiro)
|   vw_situacao_frota     → quantos carros em cada situação
|
| O faturamento entra no mês em que o carro foi DEVOLVIDO (quando o valor
| final é conhecido). O custo de manutenção entra no mês da liberação.
*/

/**
 * Últimos $meses meses: ['2026-05' => ['faturamento' =>, 'alugueis' =>, 'manutencao' =>], ...]
 * Quem não tem "financeiro" recebe só a quantidade de aluguéis (sem valores).
 */
function dados_mensais(int $meses = 6): array
{
    $inicio = date('Y-m-01', strtotime('-' . ($meses - 1) . ' months', strtotime(date('Y-m-01'))));
    $dados = [];

    for ($i = 0; $i < $meses; $i++) {
        $chave = date('Y-m', strtotime("+{$i} months", strtotime($inicio)));
        $dados[$chave] = ['faturamento' => 0.0, 'alugueis' => 0, 'manutencao' => 0.0];
    }

    if (pode('financeiro')) {
        // A visão já soma tudo: só copiamos os meses que interessam
        foreach (sb_select('vw_faturamento_mensal', ['select' => 'mes,faturamento,alugueis,manutencao']) as $linha) {
            $chave = substr($linha['mes'], 0, 7);

            if (isset($dados[$chave])) {
                $dados[$chave] = [
                    'faturamento' => (float) $linha['faturamento'],
                    'alugueis'    => (int) $linha['alugueis'],
                    'manutencao'  => (float) $linha['manutencao'],
                ];
            }
        }
    } else {
        // Sem financeiro: contamos só as devoluções de cada mês (sem valores)
        $devolvidas = sb_select('locacoes', [
            'select'         => 'data_devolucao',
            'status'         => 'eq.Finalizada',
            'data_devolucao' => 'gte.' . $inicio,
        ]);

        foreach ($devolvidas as $l) {
            $chave = substr($l['data_devolucao'], 0, 7);

            if (isset($dados[$chave])) {
                $dados[$chave]['alugueis']++;
            }
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

/** Situação da frota agora (só veículos não arquivados), pela visão do banco. */
function situacao_frota(): array
{
    $v = sb_linha('vw_situacao_frota') ?? [];

    return [
        'Disponível'    => (int) ($v['disponiveis'] ?? 0),
        'Alugado'       => (int) ($v['alugados'] ?? 0),
        'Em manutenção' => (int) ($v['em_manutencao'] ?? 0),
    ];
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
