<?php
/*
| REGRAS DE ALUGUEL
*/

const MAX_DIAS_RETROATIVO = 30; 

const ABAS_LOCACAO = [
    'andamento'   => ['texto' => 'Em andamento', 'filtro' => ['status_exibicao' => 'eq.Em andamento']],
    'atrasadas'   => ['texto' => 'Atrasados',    'filtro' => ['status_exibicao' => 'eq.Atrasada']],
    'finalizadas' => ['texto' => 'Finalizados',  'filtro' => ['status' => 'eq.Finalizada']],
    'canceladas'  => ['texto' => 'Cancelados',   'filtro' => ['status' => 'eq.Cancelada']],
    'todas'       => ['texto' => 'Todos',        'filtro' => []],
];

function filtro_locacoes(string $busca, string $de, string $ate): array
{
    $filtros = [];
    $texto = trim(str_replace([',', '(', ')', '*', '"', '\\'], ' ', $busca));

    if ($texto !== '') {
        $codigo = strtoupper(str_replace(['-', ' '], '', $texto));
        $condicoes = ["cliente_nome.ilike.*{$texto}*", "marca.ilike.*{$texto}*", "modelo.ilike.*{$texto}*", "placa.ilike.*{$codigo}*"];

        if (ctype_digit(ltrim($texto, '#'))) {
            $condicoes[] = 'id.eq.' . (int) ltrim($texto, '#'); 
        }

        $filtros['or'] = '(' . implode(',', $condicoes) . ')';
    }

    $periodo = [];

    if (validar_data($de)) {
        $periodo[] = "data_retirada.gte.{$de}";
    }

    if (validar_data($ate)) {
        $periodo[] = "data_retirada.lte.{$ate}";
    }

    if ($periodo) {
        $filtros['and'] = '(' . implode(',', $periodo) . ')';
    }

    return $filtros;
}

function buscar_locacao(int $id): ?array
{
    if ($id <= 0) {
        return null;
    }

    $l = sb_linha('locacoes', [
        'id'     => 'eq.' . $id,
        'select' => '*,'
                  . 'clientes(nome,cpf,telefone,email,cnh,cnh_validade,endereco),'
                  . 'veiculos(marca,modelo,ano,placa,chassi),'
                  . 'registrou:perfis!locacoes_usuario_id_fkey(nome),'
                  . 'encerrou:perfis!locacoes_finalizado_por_fkey(nome)',
    ]);

    if (!$l) {
        return null;
    }

    $c = $l['clientes'] ?? [];
    $l += $l['veiculos'] ?? [];
    $l['cliente'] = $c['nome'] ?? '—';
    foreach (['cpf', 'telefone', 'email', 'cnh', 'cnh_validade', 'endereco'] as $campo) {
        $l[$campo] = $c[$campo] ?? null;
    }
    $l['registrado_por'] = $l['registrou']['nome'] ?? null;
    $l['encerrado_por'] = $l['encerrou']['nome'] ?? null;

    return $l;
}

function campo_do_erro_locacao(string $mensagem): string
{
    $m = mb_strtolower($mensagem);

    return match (true) {
        str_contains($m, 'cnh'), str_contains($m, 'cliente')            => 'cliente_id',
        str_contains($m, 'quilometragem de saída')                      => 'km_saida',
        str_contains($m, 'quilometragem')                               => 'km_retorno',
        str_contains($m, 'taxa')                                        => 'taxas_extras',
        str_contains($m, 'defeito')                                     => 'defeito',
        str_contains($m, 'retirada') && !str_contains($m, 'devolução')  => 'data_retirada',
        str_contains($m, 'devolução prevista'), str_contains($m, '365') => 'data_prevista',
        str_contains($m, 'devolução')                                   => 'data_devolucao',
        str_contains($m, 'motivo')                                      => 'motivo',
        default                                                         => 'veiculo_id',
    };
}

function chamar_funcao_locacao(string $funcao, array $parametros): array
{
    try {
        return [sb_rpc($funcao, $parametros), []];
    } catch (SupabaseErro $e) {
        $frases = [
            'km_retorno_valido' => ['km_retorno', 'A quilometragem de retorno não pode ser menor que a de saída.'],
            'taxas_com_motivo'  => ['taxas_extras', 'Informe o motivo das taxas extras (ex.: combustível, limpeza, avaria).'],
        ];

        if ($regra = sb_regra($e)) {
            if (isset($frases[$regra])) {
                return [null, [$frases[$regra][0] => $frases[$regra][1]]];
            }
        }

        $mensagem = sb_mensagem_erro($e);

        return [null, [$e->codigo === 'P0001' ? campo_do_erro_locacao($mensagem) : 'geral' => $mensagem]];
    }
}

function url_assinatura(?string $caminho): ?string
{
    if (!$caminho) {
        return null;
    }

    try {
        return sb_url_assinada('contratos', $caminho, 600);
    } catch (SupabaseErro $e) {
        error_log('Não foi possível gerar o link da assinatura: ' . $e->getMessage());
        return null;
    }
}

