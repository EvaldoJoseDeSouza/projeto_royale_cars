<?php
/*
|--------------------------------------------------------------------------
| REGRAS DE MANUTENÇÃO
|--------------------------------------------------------------------------
| Como nos aluguéis, a web NÃO grava direto na tabela. Ela chama as
| funções do banco, as mesmas do desktop e do celular:
|
|   abrir_manutencao    → registra a ida à oficina (com o checklist da
|                         vistoria, se tiver) e marca o carro "Em manutenção"
|   concluir_manutencao → registra serviço, custo e data, e devolve o carro
|                         para "Disponível" (se não houver outro reparo aberto)
|
| Cada função faz tudo de uma vez (transação) e grava o histórico sozinha.
| Carro alugado vai para a oficina na DEVOLUÇÃO ("voltou com defeito").
*/

// O checklist da vistoria (mesmos itens do celular)
const CHECKLIST_MANUTENCAO = [
    'motor_ok'  => 'Motor',
    'freios_ok' => 'Freios',
    'pneus_ok'  => 'Pneus',
    'oleo_ok'   => 'Óleo',
];

const ABAS_MANUTENCAO = [
    'andamento'  => ['texto' => 'Na oficina', 'filtro' => ['status' => 'eq.Em andamento']],
    'concluidas' => ['texto' => 'Concluídas', 'filtro' => ['status' => 'eq.Concluída']],
    'todas'      => ['texto' => 'Todas',      'filtro' => []],
];

// Colunas da lista, com o carro e quem abriu "pendurados"
const COLUNAS_MANUTENCAO = 'id,veiculo_id,locacao_id,defeito,oficina,data_entrada,previsao_liberacao,data_liberacao,'
    . 'servico_realizado,custo,status,motor_ok,freios_ok,pneus_ok,oleo_ok,'
    . 'veiculos(marca,modelo,placa),abriu:perfis!manutencoes_usuario_id_fkey(nome)';

/** Tira o carro da "caixinha" e calcula há quantos dias ele está (ou ficou) parado. */
function preparar_manutencao(array $m): array
{
    $m += $m['veiculos'] ?? [];
    $m['aberto_por'] = $m['abriu']['nome'] ?? null;
    $m['dias_parado'] = dias_entre($m['data_entrada'], $m['data_liberacao'] ?? date('Y-m-d'));

    return $m;
}

function buscar_manutencao(int $id): ?array
{
    $m = $id > 0 ? sb_linha('manutencoes', ['id' => 'eq.' . $id, 'select' => COLUNAS_MANUTENCAO]) : null;

    return $m ? preparar_manutencao($m) : null;
}

/** "3/4 OK" (ou null, se não fizeram vistoria). */
function resumo_checklist(array $m): ?string
{
    $itens = array_map(fn ($chave) => $m[$chave] ?? null, array_keys(CHECKLIST_MANUTENCAO));

    if (count(array_filter($itens, fn ($v) => $v !== null)) === 0) {
        return null;
    }

    return count(array_filter($itens, fn ($v) => $v === true)) . '/4 OK';
}

/** Os itens que NÃO estavam OK na vistoria (ex.: "Freios, Óleo"). */
function itens_com_problema(array $m): string
{
    $ruins = [];

    foreach (CHECKLIST_MANUTENCAO as $chave => $nome) {
        if (($m[$chave] ?? null) === false) {
            $ruins[] = $nome;
        }
    }

    return implode(', ', $ruins);
}

/** Gasto com manutenções concluídas neste mês (para o topo da tela). */
function custo_manutencao_mes(): float
{
    $concluidas = sb_select('manutencoes', [
        'select'         => 'custo',
        'status'         => 'eq.Concluída',
        'data_liberacao' => 'gte.' . date('Y-m-01'),
    ]);

    return (float) array_sum(array_column($concluidas, 'custo'));
}

/**
 * Chama abrir_manutencao ou concluir_manutencao e devolve
 * [resultado, erros por campo]. As frases vêm prontas do banco; aqui
 * só decidimos ao lado de qual campo cada uma aparece.
 */
function chamar_funcao_manutencao(string $funcao, array $parametros): array
{
    try {
        return [sb_rpc($funcao, $parametros), []];
    } catch (SupabaseErro $e) {
        // Regras CHECK da tabela (segunda barreira)
        $frases = [
            'manutencoes_defeito_check' => ['defeito', 'Descreva o defeito ou o serviço (de 5 a 1000 caracteres).'],
            'manutencoes_oficina_check' => ['oficina', 'Nome da oficina muito longo.'],
            'manutencoes_check'         => ['previsao_liberacao', 'A previsão não pode ser antes da entrada.'],
            'manutencoes_custo_check'   => ['custo', 'O custo não pode ser negativo.'],
        ];

        if (($regra = sb_regra($e)) && isset($frases[$regra])) {
            return [null, [$frases[$regra][0] => $frases[$regra][1]]];
        }

        $mensagem = sb_mensagem_erro($e);
        $m = mb_strtolower($mensagem);

        $campo = match (true) {
            $e->codigo !== 'P0001'           => 'geral',
            str_contains($m, 'entrada')
                && !str_contains($m, 'liberação') => 'data_entrada',
            str_contains($m, 'liberação')    => 'data_liberacao',
            str_contains($m, 'serviço')      => 'servico_realizado',
            str_contains($m, 'custo')        => 'custo',
            default                          => 'veiculo_id', // "não encontrado", "está Alugado"...
        };

        return [null, [$campo => $mensagem]];
    }
}
