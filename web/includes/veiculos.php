<?php
/*
| REGRAS DE VEÍCULOS (usadas pelas telas da pasta veiculos/)
*/

const BUCKET_FOTOS = 'veiculos';
const TAMANHO_MAX_IMAGEM = 2 * 1024 * 1024; 
const KM_MAXIMO = 2000000;

const STATUS_VEICULO = ['Disponível', 'Alugado', 'Em manutenção'];

const COLUNAS_VEICULO = 'id,marca,modelo,ano,placa,chassi,valor_diaria,quilometragem,imagem,status,arquivado,arquivado_em,criado_em';

const REGRAS_VEICULO = [
    'veiculos_marca_check'         => ['marca', 'Informe a marca.'],
    'veiculos_modelo_check'        => ['modelo', 'Informe o modelo.'],
    'veiculos_ano_check'           => ['ano', 'Ano inválido.'],
    'veiculos_placa_check'         => ['placa', 'Placa inválida. Use o padrão antigo (ABC-1234) ou Mercosul (ABC1D23).'],
    'veiculos_chassi_check'        => ['chassi', 'Chassi inválido. São 17 letras/números, sem as letras I, O e Q.'],
    'veiculos_valor_diaria_check'  => ['valor_diaria', 'Informe um valor de diária maior que zero.'],
    'veiculos_quilometragem_check' => ['quilometragem', 'A quilometragem não pode ser negativa.'],
];

const DUPLICADOS_VEICULO = [
    'veiculos_placa_key'  => ['placa', 'Esta placa'],
    'veiculos_chassi_key' => ['chassi', 'Este chassi'],
];

function validar_veiculo(array $entrada, ?array $atual = null): array
{
    $dados = [
        'marca'         => trim(preg_replace('/\s+/', ' ', (string) ($entrada['marca'] ?? ''))),
        'modelo'        => trim(preg_replace('/\s+/', ' ', (string) ($entrada['modelo'] ?? ''))),
        'ano'           => trim((string) ($entrada['ano'] ?? '')),
        'placa'         => (string) ($entrada['placa'] ?? ''),
        'chassi'        => (string) ($entrada['chassi'] ?? ''),
        'valor_diaria'  => (string) ($entrada['valor_diaria'] ?? ''),
        'quilometragem' => so_digitos($entrada['quilometragem'] ?? ''),
    ];

    $erros = [];

    if (mb_strlen($dados['marca']) < 2 || mb_strlen($dados['marca']) > 100) {
        $erros['marca'] = 'Informe a marca.';
    }

    if (mb_strlen($dados['modelo']) < 1 || mb_strlen($dados['modelo']) > 100) {
        $erros['modelo'] = 'Informe o modelo.';
    }

    $anoMaximo = (int) date('Y') + 1;

    if (!ctype_digit($dados['ano']) || (int) $dados['ano'] < 1950 || (int) $dados['ano'] > $anoMaximo) {
        $erros['ano'] = "Ano inválido. Use um ano entre 1950 e {$anoMaximo}.";
    } else {
        $dados['ano'] = (int) $dados['ano'];
    }

    $placa = normalizar_placa($dados['placa']);

    if ($placa === null) {
        $erros['placa'] = 'Placa inválida. Use o padrão antigo (ABC-1234) ou Mercosul (ABC1D23).';
    } else {
        $dados['placa'] = $placa;
    }

    $chassi = normalizar_chassi($dados['chassi']);

    if ($chassi === null) {
        $erros['chassi'] = 'Chassi inválido. São 17 letras/números, sem as letras I, O e Q.';
    } else {
        $dados['chassi'] = $chassi;
    }

    $diaria = ler_dinheiro($dados['valor_diaria']);

    if ($diaria === null || $diaria <= 0 || $diaria > 100000) {
        $erros['valor_diaria'] = 'Informe um valor de diária maior que zero.';
    } else {
        $dados['valor_diaria'] = $diaria;
    }

    if ($atual && $atual['status'] === 'Alugado') {
        $dados['quilometragem'] = (int) $atual['quilometragem'];
    } elseif ($dados['quilometragem'] === '' || (int) $dados['quilometragem'] > KM_MAXIMO) {
        $erros['quilometragem'] = 'Informe a quilometragem atual do veículo (só números).';
    } else {
        $dados['quilometragem'] = (int) $dados['quilometragem'];
    }

    return [$dados, $erros];
}

function salvar_veiculo(array $dados, ?int $id = null): array
{
    try {
        $gravado = $id
            ? (sb_atualizar('veiculos', ['id' => 'eq.' . $id], $dados)[0] ?? null)
            : sb_inserir('veiculos', $dados);

        return [$gravado, []];
    } catch (SupabaseErro $e) {
        $regra = sb_regra($e);

        if (isset(DUPLICADOS_VEICULO[$regra])) {
            [$campo, $rotulo] = DUPLICADOS_VEICULO[$regra];
            return [null, [$campo => mensagem_duplicado_veiculo($campo, $rotulo, $dados[$campo], $id)]];
        }

        if (isset(REGRAS_VEICULO[$regra])) {
            [$campo, $mensagem] = REGRAS_VEICULO[$regra];
            return [null, [$campo => $mensagem]];
        }

        return [null, ['geral' => sb_mensagem_erro($e)]];
    }
}

function mensagem_duplicado_veiculo(string $campo, string $rotulo, string $valor, ?int $idAtual): string
{
    $dono = sb_linha('veiculos', [
        'select' => 'id,marca,modelo,arquivado',
        $campo   => 'eq.' . $valor,
        'id'     => 'neq.' . ($idAtual ?? 0),
    ]);

    if (!$dono) {
        return "{$rotulo} já está cadastrado.";
    }

    return "{$rotulo} já pertence ao " . nome_veiculo($dono)
        . ($dono['arquivado'] ? ' (arquivado — reative em "Veículos arquivados").' : '.');
}

function buscar_veiculo(int $id): ?array
{
    return $id > 0 ? sb_linha('veiculos', ['select' => COLUNAS_VEICULO, 'id' => 'eq.' . $id]) : null;
}


function mudar_arquivado_veiculo(int $id, bool $arquivar): array
{
    try {
        $veiculo = sb_atualizar('veiculos',
            ['id' => 'eq.' . $id, 'arquivado' => 'eq.' . ($arquivar ? 'false' : 'true')],
            ['arquivado' => $arquivar])[0] ?? null;

        return $veiculo
            ? [$veiculo, null]
            : [null, $arquivar ? 'Veículo não encontrado ou já arquivado.' : 'Veículo não encontrado ou já está na frota.'];
    } catch (SupabaseErro $e) {
        return [null, sb_mensagem_erro($e)];
    }
}

function listar_veiculos(bool $arquivados, string $busca = ''): array
{
    $filtros = [
        'select'    => COLUNAS_VEICULO,
        'arquivado' => 'eq.' . ($arquivados ? 'true' : 'false'),
        'order'     => $arquivados ? 'arquivado_em.desc' : 'marca.asc,modelo.asc',
    ];

    $texto = trim(str_replace([',', '(', ')', '*', '"', '\\'], ' ', $busca));

    if ($texto !== '') {
        $codigo = strtoupper(str_replace(['-', ' '], '', $texto)); 
        $filtros['or'] = "(marca.ilike.*{$texto}*,modelo.ilike.*{$texto}*,placa.ilike.*{$codigo}*,chassi.ilike.*{$codigo}*)";
    }

    return sb_select('veiculos', $filtros);
}

function devolucoes_previstas(): array
{
    $ativas = sb_select('locacoes', ['select' => 'veiculo_id,data_prevista', 'status' => 'eq.Em andamento']);

    return array_column($ativas, 'data_prevista', 'veiculo_id');
}

function contar_alugueis_veiculos(array $ids): array
{
    if (!$ids) {
        return [];
    }

    $contagem = [];

    foreach (sb_select('locacoes', ['select' => 'veiculo_id', 'veiculo_id' => 'in.(' . implode(',', array_map('intval', $ids)) . ')']) as $l) {
        $contagem[$l['veiculo_id']] = ($contagem[$l['veiculo_id']] ?? 0) + 1;
    }

    return $contagem;
}


/* ========================================================================
   FOTOS (Supabase Storage)
   ======================================================================== */

function enviar_foto_veiculo(?array $arquivo): array
{
    if (!$arquivo || ($arquivo['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_NO_FILE) {
        return [null, null];
    }

    if ($arquivo['error'] !== UPLOAD_ERR_OK) {
        return [null, 'Não foi possível enviar a imagem. Tente uma imagem menor que 2 MB.'];
    }

    if ($arquivo['size'] > TAMANHO_MAX_IMAGEM) {
        return [null, 'A imagem deve ter no máximo 2 MB.'];
    }

    $tipos = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
    $tipo = (new finfo(FILEINFO_MIME_TYPE))->file($arquivo['tmp_name']);

    if (!isset($tipos[$tipo]) || @getimagesize($arquivo['tmp_name']) === false) {
        return [null, 'Envie uma imagem JPG, PNG ou WEBP.'];
    }

    $nome = bin2hex(random_bytes(16)) . '.' . $tipos[$tipo];

    try {
        sb_enviar_arquivo(BUCKET_FOTOS, $nome, $arquivo['tmp_name'], $tipo);
    } catch (SupabaseErro $e) {
        return [null, 'Não foi possível guardar a foto: ' . sb_mensagem_erro($e)];
    }

    return [$nome, null];
}

function apagar_foto_veiculo(?string $nome): void
{
    if (!$nome) {
        return;
    }

    try {
        sb_apagar_arquivo(BUCKET_FOTOS, $nome);
    } catch (SupabaseErro $e) {
        error_log("Não foi possível apagar a foto {$nome}: " . $e->getMessage());
    }
}

function url_foto_veiculo(string $nome): string
{
    return sb_url_publica(BUCKET_FOTOS, $nome);
}

function imagem_veiculo(array $veiculo, string $classe = 'miniatura'): string
{
    if (!empty($veiculo['imagem'])) {
        return '<img src="' . e(url_foto_veiculo($veiculo['imagem'])) . '" alt="' . e(nome_veiculo($veiculo)) . '" class="' . e($classe) . '" loading="lazy">';
    }

    $iniciais = mb_strtoupper(mb_substr($veiculo['marca'] ?? '?', 0, 1) . mb_substr($veiculo['modelo'] ?? '', 0, 1));

    return '<div class="' . e($classe) . ' miniatura-vazia">' . e($iniciais) . '</div>';
}
