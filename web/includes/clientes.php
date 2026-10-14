<?php
/*
|--------------------------------------------------------------------------
| REGRAS DE CLIENTES (usadas no cadastro e na edição)
|--------------------------------------------------------------------------
*/

const ROTULOS_CLIENTE = [
    'nome'         => 'nome',
    'cpf'          => 'CPF',
    'cnh'          => 'CNH',
    'cnh_validade' => 'validade da CNH',
    'email'        => 'e-mail',
    'telefone'     => 'telefone',
];

/**
 * Lê e valida os dados do formulário.
 * Devolve [dados limpos, erros por campo].
 */
function validar_cliente(array $entrada, ?int $idAtual = null): array
{
    $dados = [
        'nome'         => trim(preg_replace('/\s+/', ' ', (string) ($entrada['nome'] ?? ''))),
        'cpf'          => so_digitos($entrada['cpf'] ?? ''),
        'cnh'          => so_digitos($entrada['cnh'] ?? ''),
        'cnh_validade' => trim((string) ($entrada['cnh_validade'] ?? '')),
        'email'        => mb_strtolower(trim((string) ($entrada['email'] ?? ''))),
        'telefone'     => so_digitos($entrada['telefone'] ?? ''),
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

    // Duplicidade (o banco também barra pelo UNIQUE)
    foreach (['cpf' => 'Este CPF', 'cnh' => 'Esta CNH', 'email' => 'Este e-mail'] as $campo => $rotulo) {
        if (isset($erros[$campo])) {
            continue;
        }

        $existente = db_linha(
            "SELECT id, nome, arquivado FROM clientes WHERE {$campo} = ? AND id <> ?",
            [$dados[$campo], $idAtual ?? 0]
        );

        if ($existente) {
            $erros[$campo] = mensagem_duplicado_cliente($rotulo, $existente);
        }
    }

    return [$dados, $erros];
}

function mensagem_duplicado_cliente(string $rotulo, array $existente): string
{
    if ($existente['arquivado']) {
        return "{$rotulo} pertence a {$existente['nome']}, cujo cadastro está arquivado. "
             . 'Reative o cadastro em "Clientes arquivados" em vez de criar outro.';
    }

    return "{$rotulo} já pertence ao cliente {$existente['nome']}.";
}

/** Texto para o histórico com o que mudou. Ex.: "telefone: (19) 9... → (19) 9..." */
function descrever_alteracoes_cliente(array $antes, array $depois): string
{
    $mudancas = [];

    foreach (ROTULOS_CLIENTE as $campo => $rotulo) {
        if ((string) $antes[$campo] === (string) $depois[$campo]) {
            continue;
        }

        $formatar = match ($campo) {
            'cpf'          => 'formatar_cpf',
            'telefone'     => 'formatar_telefone',
            'cnh_validade' => 'data_br',
            default        => fn ($v) => (string) $v,
        };

        $mudancas[] = $rotulo . ': ' . $formatar($antes[$campo]) . ' → ' . $formatar($depois[$campo]);
    }

    return $mudancas ? implode('; ', $mudancas) : 'nenhum dado alterado';
}

/** Situação da CNH para mostrar na tela. */
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

/** Monta o filtro de busca da lista de clientes (ativos ou arquivados). */
function filtro_clientes(bool $arquivados, string $busca): array
{
    $sql = 'c.arquivado = ?';
    $parametros = [(int) $arquivados];

    if ($busca !== '') {
        $digitos = so_digitos($busca);
        $sql .= ' AND (c.nome LIKE ? OR c.email LIKE ?';
        $parametros[] = "%{$busca}%";
        $parametros[] = "%{$busca}%";

        if ($digitos !== '') {
            $sql .= ' OR c.cpf LIKE ? OR c.telefone LIKE ? OR c.cnh LIKE ?';
            array_push($parametros, "%{$digitos}%", "%{$digitos}%", "%{$digitos}%");
        }

        $sql .= ')';
    }

    return [$sql, $parametros];
}
