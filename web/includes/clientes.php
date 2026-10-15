<?php
/*
|--------------------------------------------------------------------------
| REGRAS DE CLIENTES (usadas pelas telas da pasta clientes/)
|--------------------------------------------------------------------------
| Quem confere o quê (as mesmas regras do desktop e do celular):
|
| - A TELA ajuda quem digita: máscara no CPF e no telefone (js/app.js).
| - ESTE ARQUIVO limpa os dados (só números no CPF, CNH e telefone) e
|   confere tudo antes de enviar, para mostrar o erro ao lado do campo.
| - O BANCO (Supabase) é o juiz final: confere de novo, barra CPF, CNH e
|   e-mail repetidos, impede arquivar quem tem aluguel em andamento e
|   grava o histórico sozinho (quem cadastrou, o que mudou na edição).
|
| Nada é apagado: "arquivar" só tira o cliente da lista. O histórico de
| aluguéis continua.
*/

// As colunas que as telas usam (nunca "select *": só o que precisa)
const COLUNAS_CLIENTE = 'id,nome,cpf,cnh,cnh_validade,email,telefone,endereco,arquivado,arquivado_em,criado_em';

// Frases para cada regra do banco (nomes em banco/01 e banco/02).
// A chave do 2º nível diz em qual campo do formulário o erro aparece.
const REGRAS_CLIENTE = [
    'clientes_nome_check'     => ['nome', 'Informe o nome completo (nome e sobrenome).'],
    'clientes_cpf_check'      => ['cpf', 'CPF inválido. Confira os números digitados.'],
    'clientes_cnh_check'      => ['cnh', 'Número de CNH inválido. São 11 números.'],
    'clientes_email_check'    => ['email', 'Digite um e-mail válido.'],
    'clientes_telefone_check' => ['telefone', 'Telefone inválido. Informe DDD + número, ex.: (19) 99999-9999.'],
    'clientes_endereco_check' => ['endereco', 'O endereço pode ter no máximo 200 caracteres.'],
];

// Para o aviso de repetido: qual coluna cada regra UNIQUE protege
const DUPLICADOS_CLIENTE = [
    'clientes_cpf_key'   => ['cpf', 'Este CPF'],
    'clientes_cnh_key'   => ['cnh', 'Esta CNH'],
    'clientes_email_key' => ['email', 'Este e-mail'],
];

/**
 * Lê e confere os dados do formulário.
 * Devolve [dados limpos, erros por campo].
 */
function validar_cliente(array $entrada): array
{
    $dados = [
        'nome'         => trim(preg_replace('/\s+/', ' ', (string) ($entrada['nome'] ?? ''))),
        'cpf'          => so_digitos($entrada['cpf'] ?? ''),
        'cnh'          => so_digitos($entrada['cnh'] ?? ''),
        'cnh_validade' => trim((string) ($entrada['cnh_validade'] ?? '')),
        'email'        => mb_strtolower(trim((string) ($entrada['email'] ?? ''))),
        'telefone'     => so_digitos($entrada['telefone'] ?? ''),
        // Endereço é opcional (decisão 8): vazio vira null no banco
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

/**
 * Grava o cliente no Supabase: sem $id cadastra, com $id edita.
 * Devolve [cliente gravado ou null, erros por campo].
 *
 * Não conferimos repetidos antes (seriam 3 perguntas a mais ao banco):
 * tentamos gravar e, se o banco recusar por repetido, aí sim
 * descobrimos de quem é o CPF/CNH/e-mail para dar uma mensagem útil.
 */
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

/** "Este CPF já pertence ao cliente Ana..." (ou sugere reativar, se arquivado). */
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

/** Busca um cliente pelo id (ou null se não existir). */
function buscar_cliente(int $id): ?array
{
    return $id > 0 ? sb_linha('clientes', ['select' => COLUNAS_CLIENTE, 'id' => 'eq.' . $id]) : null;
}

/**
 * Arquiva ou reativa. Quem confere se o cliente tem aluguel em andamento
 * é o banco (tg_clientes_antes): se tiver, ele recusa com a frase pronta.
 * Devolve [cliente atualizado ou null, mensagem de erro ou null].
 */
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

/**
 * Filtros do Supabase para a lista de clientes (ativos ou arquivados).
 * A busca procura no nome e no e-mail; se tiver números, também no CPF,
 * no telefone e na CNH. Ex.: "ana" → or=(nome.ilike.*ana*,email.ilike.*ana*)
 */
function filtro_clientes(bool $arquivados, string $busca): array
{
    $filtros = ['arquivado' => 'eq.' . ($arquivados ? 'true' : 'false')];

    // Vírgula, parênteses e asterisco têm significado especial no filtro "or"
    // do Supabase: tiramos da busca para ninguém "quebrar" a pesquisa.
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

/**
 * Quantos aluguéis cada cliente da página tem, por situação.
 * Devolve [id do cliente => ['Em andamento' => 1, 'Finalizada' => 4]].
 * (Quem não tem permissão de ver aluguéis recebe tudo zerado: regra do banco.)
 */
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

/** Página da lista: [clientes, total, pagina, totalPaginas]. */
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
