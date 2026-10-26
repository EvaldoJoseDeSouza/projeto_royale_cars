<?php
/*
| REGRAS DE MANUTENÇÃO
*/

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

const COLUNAS_MANUTENCAO = 'id,veiculo_id,locacao_id,defeito,oficina,data_entrada,previsao_liberacao,data_liberacao,'
    . 'servico_realizado,custo,status,motor_ok,freios_ok,pneus_ok,oleo_ok,'
    . 'veiculos(marca,modelo,placa),abriu:perfis!manutencoes_usuario_id_fkey(nome)';

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

function resumo_checklist(array $m): ?string
{
    $itens = array_map(fn ($chave) => $m[$chave] ?? null, array_keys(CHECKLIST_MANUTENCAO));

    if (count(array_filter($itens, fn ($v) => $v !== null)) === 0) {
        return null;
    }

    return count(array_filter($itens, fn ($v) => $v === true)) . '/4 OK';
}

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

function custo_manutencao_mes(): float
{
    $concluidas = sb_select('manutencoes', [
        'select'         => 'custo',
        'status'         => 'eq.Concluída',
        'data_liberacao' => 'gte.' . date('Y-m-01'),
    ]);

    return (float) array_sum(array_column($concluidas, 'custo'));
}

function chamar_funcao_manutencao(string $funcao, array $parametros): array
{
    try {
        return [sb_rpc($funcao, $parametros), []];
    } catch (SupabaseErro $e) {
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
            default                          => 'veiculo_id', 
        };

        return [null, [$campo => $mensagem]];
    }
}
