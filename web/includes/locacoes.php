<?php
/*
|--------------------------------------------------------------------------
| REGRAS DE ALUGUEL
|--------------------------------------------------------------------------
| A web NÃO grava direto nas tabelas de aluguel. Ela chama as funções do
| banco, as mesmas que o desktop e o celular usam:
|
|   registrar_aluguel   → cria o aluguel e marca o carro como Alugado
|   registrar_devolucao → fecha o aluguel, calcula tudo e libera o carro
|                         (ou manda para a oficina, se voltou com defeito)
|   cancelar_aluguel    → cancela sem cobrar e libera o carro
|
| Cada função faz tudo de uma vez: ou dá tudo certo, ou nada é gravado
| (transação). E a conta é feita num lugar só, igual nas 3 plataformas:
|  - mínimo de 1 diária;
|  - na devolução, cobra os dias realmente usados × diária combinada
|    (devolução adiantada cobra só os dias usados — decisão 10);
|  - dias depois da data prevista aparecem como atraso (já estão somados);
|  - taxas extras (combustível, limpeza, avaria) somam ao total, com motivo.
*/

const MAX_DIAS_RETROATIVO = 30; // Pode registrar uma retirada de até 30 dias atrás (regra do banco)

// Abas da lista. "Em andamento" e "Atrasados" usam o status_exibicao da
// visão vw_locacoes, que já diz "Atrasada" quando passou da data prevista.
const ABAS_LOCACAO = [
    'andamento'   => ['texto' => 'Em andamento', 'filtro' => ['status_exibicao' => 'eq.Em andamento']],
    'atrasadas'   => ['texto' => 'Atrasados',    'filtro' => ['status_exibicao' => 'eq.Atrasada']],
    'finalizadas' => ['texto' => 'Finalizados',  'filtro' => ['status' => 'eq.Finalizada']],
    'canceladas'  => ['texto' => 'Cancelados',   'filtro' => ['status' => 'eq.Cancelada']],
    'todas'       => ['texto' => 'Todos',        'filtro' => []],
];

/**
 * Filtros da busca na lista: cliente, veículo, placa ou nº do aluguel,
 * e o período da retirada. (Mesmo cuidado dos clientes: tira a
 * "pontuação de comando" do que foi digitado.)
 */
function filtro_locacoes(string $busca, string $de, string $ate): array
{
    $filtros = [];
    $texto = trim(str_replace([',', '(', ')', '*', '"', '\\'], ' ', $busca));

    if ($texto !== '') {
        $codigo = strtoupper(str_replace(['-', ' '], '', $texto));
        $condicoes = ["cliente_nome.ilike.*{$texto}*", "marca.ilike.*{$texto}*", "modelo.ilike.*{$texto}*", "placa.ilike.*{$codigo}*"];

        if (ctype_digit(ltrim($texto, '#'))) {
            $condicoes[] = 'id.eq.' . (int) ltrim($texto, '#'); // "#15" ou "15"
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

/**
 * Um aluguel com tudo para a tela de detalhes: cliente, veículo e o nome
 * de quem registrou e de quem encerrou ("pendurados" no mesmo pedido).
 * As duas ligações com perfis precisam de nome, porque a tabela locacoes
 * aponta para perfis duas vezes (usuario_id e finalizado_por).
 */
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

    // Tira das "caixinhas" para as funções da tela (nome_veiculo, formatar_cpf...)
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

/**
 * O banco responde com frases prontas em português (ex.: "A CNH de Ana
 * venceu em..."). Aqui decidimos ao lado de qual campo cada frase aparece.
 */
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

/** Chama uma função do banco e devolve [resultado, erros por campo]. */
function chamar_funcao_locacao(string $funcao, array $parametros): array
{
    try {
        return [sb_rpc($funcao, $parametros), []];
    } catch (SupabaseErro $e) {
        // Regras CHECK da tabela (segunda barreira, caso a função deixe passar)
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

/** Assinatura do contrato (bucket privado "contratos"): link que vale 10 minutos. */
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


/* ========================================================================
   SÓ PARA AS TELAS DE MANUTENÇÃO, QUE AINDA USAM O MYSQL.
   Saem no pacote 3.6, quando a manutenção passar para o Supabase.
   ======================================================================== */

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
