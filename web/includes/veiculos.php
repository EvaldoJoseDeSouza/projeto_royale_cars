<?php
/*
|--------------------------------------------------------------------------
| REGRAS DE VEÍCULOS (usadas no cadastro e na edição)
|--------------------------------------------------------------------------
| O status do veículo NÃO é escolhido no formulário. Ele muda sozinho:
|   - Disponível    → Alugado        quando um aluguel é registrado
|   - Alugado       → Disponível     quando o carro é devolvido
|   - Disponível    → Em manutenção  quando vai para a oficina
|   - Em manutenção → Disponível     quando a manutenção é concluída
| Assim a frota nunca fica com informação errada.
*/

const PASTA_IMAGENS = 'uploads/veiculos';
const TAMANHO_MAX_IMAGEM = 2 * 1024 * 1024; // 2 MB

const STATUS_VEICULO = ['Disponível', 'Alugado', 'Em manutenção'];

function validar_veiculo(array $entrada, ?int $idAtual = null): array
{
    $dados = [
        'marca'        => trim(preg_replace('/\s+/', ' ', (string) ($entrada['marca'] ?? ''))),
        'modelo'       => trim(preg_replace('/\s+/', ' ', (string) ($entrada['modelo'] ?? ''))),
        'ano'          => trim((string) ($entrada['ano'] ?? '')),
        'placa'        => (string) ($entrada['placa'] ?? ''),
        'chassi'       => (string) ($entrada['chassi'] ?? ''),
        'valor_diaria' => (string) ($entrada['valor_diaria'] ?? ''),
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

    // Duplicidade (o banco também barra pelo UNIQUE)
    foreach (['placa' => 'Esta placa', 'chassi' => 'Este chassi'] as $campo => $rotulo) {
        if (isset($erros[$campo])) {
            continue;
        }

        $existente = db_linha(
            "SELECT id, marca, modelo, arquivado FROM veiculos WHERE {$campo} = ? AND id <> ?",
            [$dados[$campo], $idAtual ?? 0]
        );

        if ($existente) {
            $erros[$campo] = "{$rotulo} já pertence ao " . nome_veiculo($existente)
                . ($existente['arquivado'] ? ' (arquivado — reative em "Veículos arquivados").' : '.');
        }
    }

    return [$dados, $erros];
}

/**
 * Recebe a imagem enviada. Confere o tipo real do arquivo (não só a
 * extensão), o tamanho e salva com um nome aleatório.
 * Devolve [nome do arquivo ou null, mensagem de erro ou null].
 */
function salvar_imagem_veiculo(?array $arquivo): array
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

    $pasta = RAIZ . '/' . PASTA_IMAGENS;

    if (!is_dir($pasta)) {
        mkdir($pasta, 0755, true);
    }

    $nome = bin2hex(random_bytes(16)) . '.' . $tipos[$tipo];

    if (!move_uploaded_file($arquivo['tmp_name'], $pasta . '/' . $nome)) {
        return [null, 'Não foi possível salvar a imagem no servidor.'];
    }

    return [$nome, null];
}

function apagar_imagem_veiculo(?string $nome): void
{
    if ($nome && preg_match('/^[a-f0-9]{32}\.(jpg|png|webp)$/', $nome)) {
        $caminho = RAIZ . '/' . PASTA_IMAGENS . '/' . $nome;

        if (is_file($caminho)) {
            unlink($caminho);
        }
    }
}

/** Foto do veículo ou um quadro com as iniciais. */
function imagem_veiculo(array $veiculo, string $classe = 'miniatura'): string
{
    if (!empty($veiculo['imagem'])) {
        return '<img src="' . e(url(PASTA_IMAGENS . '/' . $veiculo['imagem'])) . '" alt="' . e(nome_veiculo($veiculo)) . '" class="' . e($classe) . '">';
    }

    $iniciais = mb_strtoupper(mb_substr($veiculo['marca'] ?? '?', 0, 1) . mb_substr($veiculo['modelo'] ?? '', 0, 1));

    return '<div class="' . e($classe) . ' miniatura-vazia">' . e($iniciais) . '</div>';
}

function descrever_alteracoes_veiculo(array $antes, array $depois): string
{
    $rotulos = ['marca' => 'marca', 'modelo' => 'modelo', 'ano' => 'ano', 'placa' => 'placa', 'chassi' => 'chassi', 'valor_diaria' => 'diária'];
    $mudancas = [];

    foreach ($rotulos as $campo => $rotulo) {
        $a = $antes[$campo];
        $d = $depois[$campo];

        if ($campo === 'valor_diaria') {
            if (abs((float) $a - (float) $d) < 0.005) {
                continue;
            }

            $mudancas[] = "diária de " . moeda($a) . ' para ' . moeda($d);
            continue;
        }

        if ((string) $a !== (string) $d) {
            $mudancas[] = "{$rotulo}: {$a} → {$d}";
        }
    }

    return $mudancas ? implode('; ', $mudancas) : 'nenhum dado alterado';
}
