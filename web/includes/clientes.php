<?php
/*
| REGRAS DE CLIENTES 
*/

const COLUNAS_CLIENTE = 'id,nome,cpf,cnh,cnh_validade,email,telefone,endereco,arquivado,arquivado_em,criado_em';

const REGRAS_CLIENTE = [
    'clientes_nome_check'     => ['nome', 'Informe o nome completo (nome e sobrenome).'],
    'clientes_cpf_check'      => ['cpf', 'CPF inválido. Confira os números digitados.'],
    'clientes_cnh_check'      => ['cnh', 'Número de CNH inválido. São 11 números.'],
    'clientes_email_check'    => ['email', 'Digite um e-mail válido.'],
    'clientes_telefone_check' => ['telefone', 'Telefone inválido. Informe DDD + número, ex.: (19) 99999-9999.'],
    'clientes_endereco_check' => ['endereco', 'O endereço pode ter no máximo 200 caracteres.'],
];

const DUPLICADOS_CLIENTE = [
    'clientes_cpf_key'   => ['cpf', 'Este CPF'],
    'clientes_cnh_key'   => ['cnh', 'Esta CNH'],
    'clientes_email_key' => ['email', 'Este e-mail'],
];

function validar_cliente(array $entrada): array
{
    $dados = [
        'nome'         => trim(preg_replace('/\s+/', ' ', (string) ($entrada['nome'] ?? ''))),
        'cpf'          => so_digitos($entrada['cpf'] ?? ''),
        'cnh'          => so_digitos($entrada['cnh'] ?? ''),
        'cnh_validade' => trim((string) ($entrada['cnh_validade'] ?? '')),
        'email'        => mb_strtolower(trim((string) ($entrada['email'] ?? ''))),
        'telefone'     => so_digitos($entrada['telefone'] ?? ''),
        'endereco'     => trim(preg_replace('/\s+/', ' ', (string) ($entrada['endereco'] ?? ''))) ?: null,
    ];

    $erros = [];

    if (!validar_nome_completo($dados['nome'])) {
        $erros['nome'] = 'Informe o nome completo (nome e sobrenome, só letras).';
    }

    if (!validar_cpf($dados['cpf'])) {
        $erros['cpf'] = 'CPF inválido. Confira os números digitados.';
    }

    if (!validar_cnh($dados['cnh'])) {
        $erros['cnh'] = 'Número de CNH inválido. São 11 números, sem letras.';
    }

    if (!validar_data($dados['cnh_validade'])) {
        $erros['cnh_validade'] = 'Informe a data de validade da CNH.';
    } elseif ($dados['cnh_validade'] < date('Y-m-d', strtotime('-10 years'))
           || $dados['cnh_validade'] > date('Y-m-d', strtotime('+15 years'))) {
        $erros['cnh_validade'] = 'Validade da CNH fora do esperado. Confira a data.';
    }

    if (!validar_email($dados['email'])) {
        $erros['email'] = 'Digite um e-mail válido.';
    }

    if (!validar_telefone($dados['telefone'])) {
        $erros['telefone'] = 'Telefone inválido. Informe DDD + número, ex.: (19) 99999-9999.';
    }

    if ($dados['endereco'] !== null && mb_strlen($dados['endereco']) > 200) {
        $erros['endereco'] = 'O endereço pode ter no máximo 200 caracteres.';
    }

    return [$dados, $erros];
}

function salvar_cliente(array $dados, ?int $id = null): array
{
    try {
        $gravado = $id
            ? (sb_atualizar('clientes', ['id' => 'eq.' . $id], $dados)[0] ?? null)
            : sb_inserir('clientes', $dados);

        return [$gravado, []];
    } catch (SupabaseErro $e) {
        $regra = sb_regra($e);

        if (isset(DUPLICADOS_CLIENTE[$regra])) {
            [$campo, $rotulo] = DUPLICADOS_CLIENTE[$regra];
            return [null, [$campo => mensagem_duplicado_cliente($campo, $rotulo, $dados[$campo], $id)]];
        }

        if (isset(REGRAS_CLIENTE[$regra])) {
            [$campo, $mensagem] = REGRAS_CLIENTE[$regra];
            return [null, [$campo => $mensagem]];
        }

        return [null, ['geral' => sb_mensagem_erro($e)]];
    }
}

function mensagem_duplicado_cliente(string $campo, string $rotulo, string $valor, ?int $idAtual): string
{
    $dono = sb_linha('clientes', [
        'select' => 'id,nome,arquivado',
        $campo   => 'eq.' . $valor,
        'id'     => 'neq.' . ($idAtual ?? 0),
    ]);

    if (!$dono) {
        return "{$rotulo} já está cadastrado.";
    }

    if ($dono['arquivado']) {
        return "{$rotulo} pertence a {$dono['nome']}, cujo cadastro está arquivado. "
             . 'Reative o cadastro em "Clientes arquivados" em vez de criar outro.';
    }

    return "{$rotulo} já pertence ao cliente {$dono['nome']}.";
}

function buscar_cliente(int $id): ?array
{
    return $id > 0 ? sb_linha('clientes', ['select' => COLUNAS_CLIENTE, 'id' => 'eq.' . $id]) : null;
}

function mudar_arquivado_cliente(int $id, bool $arquivar): array
{
    try {
        $cliente = sb_atualizar('clientes',
            ['id' => 'eq.' . $id, 'arquivado' => 'eq.' . ($arquivar ? 'false' : 'true')],
            ['arquivado' => $arquivar])[0] ?? null;

        return $cliente
            ? [$cliente, null]
            : [null, $arquivar ? 'Cliente não encontrado ou já arquivado.' : 'Cliente não encontrado ou já está ativo.'];
    } catch (SupabaseErro $e) {
        return [null, sb_mensagem_erro($e)];
    }
}

function situacao_cnh(string $validade): string
{
    $dias = dias_entre(date('Y-m-d'), $validade);

    if ($dias < 0) {
        return '<span class="status status-vermelho">Vencida</span>';
    }

    if ($dias <= DIAS_AVISO_CNH) {
        return '<span class="status status-laranja">Vence em ' . $dias . ' dia(s)</span>';
    }

    return '';
}

function filtro_clientes(bool $arquivados, string $busca): array
{
    $filtros = ['arquivado' => 'eq.' . ($arquivados ? 'true' : 'false')];

    $texto = trim(str_replace([',', '(', ')', '*', '"', '\\'], ' ', $busca));

    if ($texto !== '') {
        $condicoes = ["nome.ilike.*{$texto}*", "email.ilike.*{$texto}*"];
        $digitos = so_digitos($texto);

        if ($digitos !== '') {
            array_push($condicoes, "cpf.ilike.*{$digitos}*", "telefone.ilike.*{$digitos}*", "cnh.ilike.*{$digitos}*");
        }

        $filtros['or'] = '(' . implode(',', $condicoes) . ')';
    }

    return $filtros;
}

function contar_alugueis_clientes(array $ids): array
{
    if (!$ids) {
        return [];
    }

    $locacoes = sb_select('locacoes', [
        'select'     => 'cliente_id,status',
        'cliente_id' => 'in.(' . implode(',', array_map('intval', $ids)) . ')',
    ]);

    $contagem = [];

    foreach ($locacoes as $l) {
        $contagem[$l['cliente_id']][$l['status']] = ($contagem[$l['cliente_id']][$l['status']] ?? 0) + 1;
    }

    return $contagem;
}

function listar_clientes(bool $arquivados, string $busca, string $ordem): array
{
    $filtros = filtro_clientes($arquivados, $busca);
    $total = sb_contar('clientes', $filtros);
    [$limite, $offset, $pagina, $totalPaginas] = paginar($total);

    $clientes = sb_select('clientes', $filtros + [
        'select' => COLUNAS_CLIENTE,
        'order'  => $ordem,
        'limit'  => $limite,
        'offset' => $offset,
    ]);

    return [$clientes, $total, $pagina, $totalPaginas];
}
