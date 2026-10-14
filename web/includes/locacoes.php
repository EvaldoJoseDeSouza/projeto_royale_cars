<?php
/*
|--------------------------------------------------------------------------
| REGRAS DE ALUGUEL
|--------------------------------------------------------------------------
| Cobrança:
|  - Mínimo de 1 diária.
|  - Na devolução, cobra os dias realmente usados × diária combinada.
|  - Se passar da data prevista, os dias extras aparecem como atraso
|    (também cobrados pela diária combinada).
*/

const MAX_DIAS_LOCACAO      = 365; // Período máximo de um aluguel
const MAX_DIAS_RETROATIVO   = 30;  // Pode registrar uma retirada de até 30 dias atrás

function calcular_previsto(string $retirada, string $prevista, float $diaria): array
{
    $dias = max(1, dias_entre($retirada, $prevista));

    return ['dias' => $dias, 'valor' => round($dias * $diaria, 2)];
}

function calcular_devolucao(array $locacao, string $dataDevolucao): array
{
    $diaria = (float) $locacao['valor_diaria'];
    $dias = max(1, dias_entre($locacao['data_retirada'], $dataDevolucao));
    $atraso = max(0, dias_entre($locacao['data_prevista'], $dataDevolucao));

    return [
        'dias'         => $dias,
        'dias_atraso'  => $atraso,
        'valor_atraso' => round($atraso * $diaria, 2),
        'valor_total'  => round($dias * $diaria, 2),
    ];
}

/** Executa várias operações como uma só: ou tudo dá certo, ou nada é gravado. */
function em_transacao(callable $operacao)
{
    global $conexao;

    $conexao->begin_transaction();

    try {
        $resultado = $operacao();
        $conexao->commit();

        return $resultado;
    } catch (Throwable $erro) {
        $conexao->rollback();
        throw $erro;
    }
}

/** Erro de regra de negócio (mensagem pode ser mostrada ao usuário). */
class RegraNegocio extends Exception
{
}
