<?php
/*
| CLIENTE DO SUPABASE EM PHP
*/

class SupabaseErro extends RuntimeException
{
    public string $codigo;      
    public string $detalhes;    
    public int $status;         

    public function __construct(string $mensagem, string $codigo = '', string $detalhes = '', int $status = 0)
    {
        parent::__construct($mensagem);
        $this->codigo = $codigo;
        $this->detalhes = $detalhes;
        $this->status = $status;
    }
}

// ----------------------------------------------------------- CONFIGURAÇÃO

function sb_config(): array
{
    static $config = null;

    if ($config === null) {
        $local = RAIZ . '/config/config.local.php';
        $config = require (is_file($local) ? $local : RAIZ . '/config/config.exemplo.php');
        $config['supabase_url'] = rtrim($config['supabase_url'], '/');
    }

    return $config;
}

function sb_certificado(): ?string
{
    $configurado = sb_config()['ca_bundle'] ?? null;

    $candidatos = array_filter([
        $configurado,
        ini_get('curl.cainfo') ?: null,
        ini_get('openssl.cafile') ?: null,
        'C:/xampp/apache/bin/curl-ca-bundle.crt',
        'C:/xampp/php/extras/ssl/cacert.pem',
    ]);

    foreach ($candidatos as $arquivo) {
        if (is_file($arquivo)) {
            return $arquivo;
        }
    }

    return null; 
}

// --------------------------------------------------------- O PEDIDO EM SI
function sb_requisicao(string $metodo, string $caminho, $corpo = null, array $cabecalhos = [], bool $comLogin = true): array
{
    if (!function_exists('curl_init')) {
        throw new SupabaseErro('A extensão curl do PHP está desligada. No XAMPP: Config → php.ini → tire o ";" da linha "extension=curl" e reinicie o Apache.', 'sem_curl');
    }

    $config = sb_config();

    $token = $comLogin ? (sb_token_atual() ?? $config['supabase_chave']) : $config['supabase_chave'];

    $lista = [
        'apikey: ' . $config['supabase_chave'],
        'Authorization: Bearer ' . $token,
        'Accept: application/json',
    ];

    if (is_array($corpo)) {
        $lista[] = 'Content-Type: application/json';
        $corpo = $corpo === [] ? '{}' : json_encode($corpo, JSON_UNESCAPED_UNICODE);
    }

    foreach ($cabecalhos as $nome => $valor) {
        $lista[] = "$nome: $valor";
    }

    $recebidos = [];
    $ch = curl_init($config['supabase_url'] . $caminho);
    curl_setopt_array($ch, [
        CURLOPT_CUSTOMREQUEST  => $metodo,
        CURLOPT_HTTPHEADER     => $lista,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_TIMEOUT        => 30,
        CURLOPT_HEADERFUNCTION => function ($ch, $linha) use (&$recebidos) {
            $partes = explode(':', $linha, 2);
            if (count($partes) === 2) {
                $recebidos[strtolower(trim($partes[0]))] = trim($partes[1]);
            }
            return strlen($linha);
        },
    ]);

    if ($corpo !== null) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, $corpo);
    }

    if ($certificado = sb_certificado()) {
        curl_setopt($ch, CURLOPT_CAINFO, $certificado);
    }

    $resposta = curl_exec($ch);
    $status = (int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
    $falhaRede = curl_error($ch);
    curl_close($ch);

    if ($resposta === false) {
        error_log('Supabase sem resposta: ' . $falhaRede);
        $dica = stripos($falhaRede, 'SSL') !== false || stripos($falhaRede, 'certificate') !== false
            ? ' (problema de certificado SSL: abra diagnostico.php)'
            : ' Verifique a internet.';
        throw new SupabaseErro('Não foi possível falar com o servidor.' . $dica, 'sem_conexao', $falhaRede);
    }

    $dados = $resposta === '' ? null : json_decode($resposta, true);

    if ($status >= 400) {
        throw sb_erro_da_resposta($dados, $status, $resposta);
    }

    return ['status' => $status, 'dados' => $dados, 'cabecalhos' => $recebidos];
}
function sb_erro_da_resposta($dados, int $status, string $bruto): SupabaseErro
{
    $dados = is_array($dados) ? $dados : [];

    $mensagem = $dados['message'] ?? $dados['msg'] ?? $dados['erro'] ?? $dados['error_description'] ?? $dados['error'] ?? $bruto;
    $codigo = (string) ($dados['error_code'] ?? $dados['code'] ?? $dados['statusCode'] ?? $status);
    $detalhes = (string) ($dados['details'] ?? $dados['hint'] ?? '');

    error_log("Supabase recusou ($status/$codigo): $mensagem $detalhes");

    return new SupabaseErro((string) $mensagem, $codigo, $detalhes, $status);
}

function sb_parametros(array $filtros): string
{
    return $filtros ? '?' . http_build_query($filtros, '', '&', PHP_QUERY_RFC3986) : '';
}

// ------------------------------------------------------ DADOS (TABELAS)
function sb_select(string $tabela, array $filtros = []): array
{
    return sb_requisicao('GET', "/rest/v1/$tabela" . sb_parametros($filtros))['dados'] ?? [];
}

function sb_linha(string $tabela, array $filtros = []): ?array
{
    $filtros['limit'] = 1;
    return sb_select($tabela, $filtros)[0] ?? null;
}

function sb_contar(string $tabela, array $filtros = []): int
{
    $filtros['select'] = $filtros['select'] ?? 'id';
    $filtros['limit'] = 1;
    $resposta = sb_requisicao('GET', "/rest/v1/$tabela" . sb_parametros($filtros), null, ['Prefer' => 'count=exact']);

    $faixa = $resposta['cabecalhos']['content-range'] ?? '*/0';
    return (int) substr($faixa, strpos($faixa, '/') + 1);
}

function sb_inserir(string $tabela, array $dados): array
{
    $gravado = sb_requisicao('POST', "/rest/v1/$tabela", $dados, ['Prefer' => 'return=representation'])['dados'] ?? [];
    return array_is_list($dados) ? $gravado : ($gravado[0] ?? []);
}

function sb_atualizar(string $tabela, array $filtros, array $dados): array
{
    if (!$filtros) {
        throw new InvalidArgumentException('sb_atualizar sem filtro mudaria a tabela inteira.');
    }
    return sb_requisicao('PATCH', "/rest/v1/$tabela" . sb_parametros($filtros), $dados, ['Prefer' => 'return=representation'])['dados'] ?? [];
}

function sb_apagar(string $tabela, array $filtros): void
{
    if (!$filtros) {
        throw new InvalidArgumentException('sb_apagar sem filtro apagaria a tabela inteira.');
    }
    sb_requisicao('DELETE', "/rest/v1/$tabela" . sb_parametros($filtros));
}

function sb_rpc(string $funcao, array $parametros = [], bool $comLogin = true)
{
    return sb_requisicao('POST', "/rest/v1/rpc/$funcao", $parametros, [], $comLogin)['dados'];
}

function sb_funcao(string $nome, array $corpo)
{
    return sb_requisicao('POST', "/functions/v1/$nome", $corpo)['dados'];
}

// ------------------------------------------------------------- LOGIN (AUTH)
function sb_token_atual(): ?string
{
    $sessao = $_SESSION['supabase'] ?? null;

    if (!$sessao) {
        return null;
    }
    if ($sessao['expira_em'] - 60 < time()) {
        try {
            $novo = sb_requisicao('POST', '/auth/v1/token?grant_type=refresh_token',
                ['refresh_token' => $sessao['refresh_token']], [], false)['dados'];
            sb_guardar_sessao($novo);
        } catch (SupabaseErro $e) {
            if ($e->codigo === 'sem_conexao') {
                throw $e; 
            }
            unset($_SESSION['supabase']); 
            return null;
        }
    }

    return $_SESSION['supabase']['token'];
}

function sb_guardar_sessao(array $resposta): void
{
    $_SESSION['supabase'] = [
        'token'         => $resposta['access_token'],
        'refresh_token' => $resposta['refresh_token'],
        'expira_em'     => (int) ($resposta['expires_at'] ?? time() + (int) ($resposta['expires_in'] ?? 3600)),
        'usuario_id'    => $resposta['user']['id'] ?? null,
    ];
}

function sb_entrar(string $email, string $senha): void
{
    $resposta = sb_requisicao('POST', '/auth/v1/token?grant_type=password',
        ['email' => $email, 'password' => $senha], [], false)['dados'];
    sb_guardar_sessao($resposta);
}

function sb_trocar_senha(string $novaSenha): void
{
    sb_requisicao('PUT', '/auth/v1/user', ['password' => $novaSenha]);
}

function sb_sair(): void
{
    try {
        if (!empty($_SESSION['supabase'])) {
            sb_requisicao('POST', '/auth/v1/logout');
        }
    } catch (SupabaseErro $e) {
    }
    unset($_SESSION['supabase']);
}

// --------------------------------------------------------- ARQUIVOS (STORAGE)
function sb_enviar_arquivo(string $bucket, string $caminho, string $arquivoLocal, string $tipo): void
{
    sb_requisicao('POST', "/storage/v1/object/$bucket/$caminho", file_get_contents($arquivoLocal),
        ['Content-Type' => $tipo, 'x-upsert' => 'true']);
}

function sb_apagar_arquivo(string $bucket, string $caminho): void
{
    sb_requisicao('DELETE', "/storage/v1/object/$bucket/$caminho");
}

function sb_url_publica(string $bucket, string $caminho): string
{
    return sb_config()['supabase_url'] . "/storage/v1/object/public/$bucket/" . str_replace('%2F', '/', rawurlencode($caminho));
}

function sb_url_assinada(string $bucket, string $caminho, int $segundos = 600): string
{
    $resposta = sb_requisicao('POST', "/storage/v1/object/sign/$bucket/$caminho", ['expiresIn' => $segundos])['dados'];
    return sb_config()['supabase_url'] . '/storage/v1' . $resposta['signedURL'];
}

// --------------------------------------------------------------- ERROS
function sb_regra(SupabaseErro $e): ?string
{
    return preg_match('/constraint "([^"]+)"/', $e->getMessage() . ' ' . $e->detalhes, $achado) ? $achado[1] : null;
}

function sb_mensagem_erro(SupabaseErro $e, array $mensagens = []): string
{
    $regra = sb_regra($e);

    if ($regra && isset($mensagens[$regra])) {
        return $mensagens[$regra];
    }

    return match ($e->codigo) {
        'P0001'                 => $e->getMessage(), 
        '23505'                 => 'Já existe um cadastro com estes dados.',
        '23514', '23502'        => 'Algum campo não passou na conferência do banco. Confira os dados digitados.',
        '42501'                 => 'Você não tem permissão para fazer isso.',
        'sem_conexao', 'sem_curl' => $e->getMessage(),
        default                 => 'Não foi possível concluir. Tente de novo em instantes.',
    };
}
