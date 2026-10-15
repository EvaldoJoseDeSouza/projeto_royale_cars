<?php
/*
|--------------------------------------------------------------------------
| CLIENTE DO SUPABASE EM PHP
|--------------------------------------------------------------------------
| O desktop usa a biblioteca supabase-js e o celular usa a supabase_flutter.
| Para PHP não existe uma oficial, então fizemos a nossa: este arquivo.
|
| Como funciona: o Supabase responde a pedidos pela internet (uma "API").
| Cada função aqui monta um pedido, envia com o curl (o "navegador" do PHP)
| e devolve a resposta já como array do PHP.
|
|   sb_select('clientes', ['arquivado' => 'eq.false'])   → lista de clientes
|   sb_rpc('registrar_aluguel', [...])                   → chama função do banco
|   sb_entrar($email, $senha)                            → faz o login
|
| Quem está logado: o Supabase devolve um "crachá" (token) no login. Ele
| fica guardado na sessão do PHP e vai junto em todo pedido. É com ele que
| o banco sabe QUEM está pedindo e aplica as regras de acesso (RLS).
|
| Se o Supabase recusar algo, as funções lançam um SupabaseErro (use
| try/catch) e sb_mensagem_erro() transforma o erro em frase para a tela.
|
| Filtros (o mesmo jeito do Supabase, chamado PostgREST):
|   'status'        => 'eq.Disponível'      igual a
|   'valor_diaria'  => 'gt.100'             maior que   (gte, lt, lte também)
|   'nome'          => 'ilike.*ana*'        contém, sem ligar para maiúsculas
|   'id'            => 'in.(1,2,3)'         está na lista
|   'select'        => 'id,nome,clientes(nome)'   quais colunas trazer
|   'order'         => 'nome.asc'           ordem
|   'limit'         => 20                   quantos no máximo
*/

class SupabaseErro extends RuntimeException
{
    public string $codigo;      // ex.: "23505" (repetido), "P0001" (frase nossa), "invalid_credentials"
    public string $detalhes;    // texto técnico extra (quando houver)
    public int $status;         // código HTTP: 400, 401, 403, 404, 500...

    public function __construct(string $mensagem, string $codigo = '', string $detalhes = '', int $status = 0)
    {
        parent::__construct($mensagem);
        $this->codigo = $codigo;
        $this->detalhes = $detalhes;
        $this->status = $status;
    }
}

// ----------------------------------------------------------- CONFIGURAÇÃO

/** Lê a configuração: config.local.php se existir, senão o modelo. */
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

/**
 * Certificado SSL. O PHP só conversa com https se confiar no certificado do
 * site. No Windows o XAMPP traz um arquivo com os certificados conhecidos,
 * mas nem sempre o php.ini aponta para ele. Aqui procuramos nos lugares de
 * sempre. (Nunca desligamos a verificação: seria abrir a porta para golpes.)
 */
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

    return null; // Linux/Mac: o sistema já sabe onde estão os certificados
}

// --------------------------------------------------------- O PEDIDO EM SI

/**
 * Faz um pedido ao Supabase e devolve ['status' => 200, 'dados' => ..., 'cabecalhos' => [...]].
 * $corpo: array (vira JSON) ou string (enviada como está, ex.: uma foto).
 */
function sb_requisicao(string $metodo, string $caminho, $corpo = null, array $cabecalhos = [], bool $comLogin = true): array
{
    if (!function_exists('curl_init')) {
        throw new SupabaseErro('A extensão curl do PHP está desligada. No XAMPP: Config → php.ini → tire o ";" da linha "extension=curl" e reinicie o Apache.', 'sem_curl');
    }

    $config = sb_config();

    // O "crachá": o token de quem está logado ou, sem login, a chave pública
    $token = $comLogin ? (sb_token_atual() ?? $config['supabase_chave']) : $config['supabase_chave'];

    $lista = [
        'apikey: ' . $config['supabase_chave'],
        'Authorization: Bearer ' . $token,
        'Accept: application/json',
    ];

    if (is_array($corpo)) {
        $lista[] = 'Content-Type: application/json';
        // Array vazio vira "{}" (objeto vazio). Sem isso, o PHP mandaria "[]".
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
        // Guarda os cabeçalhos da resposta (o total de linhas vem num deles)
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

/**
 * Cada parte do Supabase devolve o erro de um jeito:
 *   banco (PostgREST): {code, message, details}
 *   login (Auth):      {error_code, msg}
 *   arquivos/funções:  {error, message} ou {erro}
 * Aqui juntamos tudo num SupabaseErro só.
 */
function sb_erro_da_resposta($dados, int $status, string $bruto): SupabaseErro
{
    $dados = is_array($dados) ? $dados : [];

    $mensagem = $dados['message'] ?? $dados['msg'] ?? $dados['erro'] ?? $dados['error_description'] ?? $dados['error'] ?? $bruto;
    // error_code primeiro: o login manda {"code": 400, "error_code": "invalid_credentials"}
    // e o que nos interessa é o nome do erro, não o número.
    $codigo = (string) ($dados['error_code'] ?? $dados['code'] ?? $dados['statusCode'] ?? $status);
    $detalhes = (string) ($dados['details'] ?? $dados['hint'] ?? '');

    error_log("Supabase recusou ($status/$codigo): $mensagem $detalhes");

    return new SupabaseErro((string) $mensagem, $codigo, $detalhes, $status);
}

/** Monta "?coluna=eq.valor&order=..." a partir do array de filtros. */
function sb_parametros(array $filtros): string
{
    return $filtros ? '?' . http_build_query($filtros, '', '&', PHP_QUERY_RFC3986) : '';
}

// ------------------------------------------------------ DADOS (TABELAS)

/** Lista de linhas. Ex.: sb_select('veiculos', ['status' => 'eq.Disponível', 'order' => 'marca.asc']) */
function sb_select(string $tabela, array $filtros = []): array
{
    return sb_requisicao('GET', "/rest/v1/$tabela" . sb_parametros($filtros))['dados'] ?? [];
}

/** Uma linha só (ou null se não achar). Ex.: sb_linha('clientes', ['id' => 'eq.5']) */
function sb_linha(string $tabela, array $filtros = []): ?array
{
    $filtros['limit'] = 1;
    return sb_select($tabela, $filtros)[0] ?? null;
}

/** Quantas linhas existem com esse filtro (sem baixar as linhas). */
function sb_contar(string $tabela, array $filtros = []): int
{
    $filtros['select'] = $filtros['select'] ?? 'id';
    $filtros['limit'] = 1;
    $resposta = sb_requisicao('GET', "/rest/v1/$tabela" . sb_parametros($filtros), null, ['Prefer' => 'count=exact']);

    // O total vem no cabeçalho Content-Range, assim: "0-0/42"
    $faixa = $resposta['cabecalhos']['content-range'] ?? '*/0';
    return (int) substr($faixa, strpos($faixa, '/') + 1);
}

/** Grava uma linha nova (ou várias, se $dados for uma lista) e devolve o que foi gravado. */
function sb_inserir(string $tabela, array $dados): array
{
    $gravado = sb_requisicao('POST', "/rest/v1/$tabela", $dados, ['Prefer' => 'return=representation'])['dados'] ?? [];
    return array_is_list($dados) ? $gravado : ($gravado[0] ?? []);
}

/** Altera as linhas que passam no filtro. Ex.: sb_atualizar('clientes', ['id' => 'eq.5'], ['telefone' => '19...']) */
function sb_atualizar(string $tabela, array $filtros, array $dados): array
{
    if (!$filtros) {
        throw new InvalidArgumentException('sb_atualizar sem filtro mudaria a tabela inteira.');
    }
    return sb_requisicao('PATCH', "/rest/v1/$tabela" . sb_parametros($filtros), $dados, ['Prefer' => 'return=representation'])['dados'] ?? [];
}

/** Apaga as linhas que passam no filtro (só onde o banco permitir). */
function sb_apagar(string $tabela, array $filtros): void
{
    if (!$filtros) {
        throw new InvalidArgumentException('sb_apagar sem filtro apagaria a tabela inteira.');
    }
    sb_requisicao('DELETE', "/rest/v1/$tabela" . sb_parametros($filtros));
}

/** Chama uma função do banco. Ex.: sb_rpc('cancelar_aluguel', ['p_locacao_id' => 3, 'p_motivo' => '...']) */
function sb_rpc(string $funcao, array $parametros = [], bool $comLogin = true)
{
    return sb_requisicao('POST', "/rest/v1/rpc/$funcao", $parametros, [], $comLogin)['dados'];
}

/** Chama uma Edge Function (ex.: admin-usuarios). Devolve a resposta dela. */
function sb_funcao(string $nome, array $corpo)
{
    return sb_requisicao('POST', "/functions/v1/$nome", $corpo)['dados'];
}

// ------------------------------------------------------------- LOGIN (AUTH)

/** Token de quem está logado. Se estiver quase vencendo, renova antes. */
function sb_token_atual(): ?string
{
    $sessao = $_SESSION['supabase'] ?? null;

    if (!$sessao) {
        return null;
    }

    // O token dura 1 hora. Faltando menos de 1 minuto, pedimos outro.
    if ($sessao['expira_em'] - 60 < time()) {
        try {
            $novo = sb_requisicao('POST', '/auth/v1/token?grant_type=refresh_token',
                ['refresh_token' => $sessao['refresh_token']], [], false)['dados'];
            sb_guardar_sessao($novo);
        } catch (SupabaseErro $e) {
            if ($e->codigo === 'sem_conexao') {
                throw $e; // sem internet: avisa, mas NÃO tira a pessoa do sistema
            }
            unset($_SESSION['supabase']); // o Supabase recusou: precisa entrar de novo
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

/** Login com e-mail e senha. Lança SupabaseErro se recusar. */
function sb_entrar(string $email, string $senha): void
{
    $resposta = sb_requisicao('POST', '/auth/v1/token?grant_type=password',
        ['email' => $email, 'password' => $senha], [], false)['dados'];
    sb_guardar_sessao($resposta);
}

/** Troca a senha de quem está logado. */
function sb_trocar_senha(string $novaSenha): void
{
    sb_requisicao('PUT', '/auth/v1/user', ['password' => $novaSenha]);
}

/** Sai: avisa o Supabase (o token deixa de valer) e esquece o token. */
function sb_sair(): void
{
    try {
        if (!empty($_SESSION['supabase'])) {
            sb_requisicao('POST', '/auth/v1/logout');
        }
    } catch (SupabaseErro $e) {
        // Mesmo sem internet, a sessão local é apagada abaixo
    }
    unset($_SESSION['supabase']);
}

// --------------------------------------------------------- ARQUIVOS (STORAGE)

/** Envia um arquivo (ex.: foto do carro). upsert = substitui se já existir. */
function sb_enviar_arquivo(string $bucket, string $caminho, string $arquivoLocal, string $tipo): void
{
    sb_requisicao('POST', "/storage/v1/object/$bucket/$caminho", file_get_contents($arquivoLocal),
        ['Content-Type' => $tipo, 'x-upsert' => 'true']);
}

function sb_apagar_arquivo(string $bucket, string $caminho): void
{
    sb_requisicao('DELETE', "/storage/v1/object/$bucket/$caminho");
}

/** Endereço de um arquivo de bucket público (ex.: fotos dos veículos). */
function sb_url_publica(string $bucket, string $caminho): string
{
    return sb_config()['supabase_url'] . "/storage/v1/object/public/$bucket/" . str_replace('%2F', '/', rawurlencode($caminho));
}

/** Endereço temporário de um arquivo de bucket privado (ex.: assinatura do contrato). */
function sb_url_assinada(string $bucket, string $caminho, int $segundos = 600): string
{
    $resposta = sb_requisicao('POST', "/storage/v1/object/sign/$bucket/$caminho", ['expiresIn' => $segundos])['dados'];
    return sb_config()['supabase_url'] . '/storage/v1' . $resposta['signedURL'];
}

// --------------------------------------------------------------- ERROS

/** Nome da regra do banco que falhou (ex.: "clientes_cpf_key"), se houver. */
function sb_regra(SupabaseErro $e): ?string
{
    return preg_match('/constraint "([^"]+)"/', $e->getMessage() . ' ' . $e->detalhes, $achado) ? $achado[1] : null;
}

/**
 * Transforma o erro numa frase para a tela. $mensagens é um "dicionário"
 * de cada tela: ['clientes_cpf_check' => 'CPF inválido...'].
 * (É o mesmo tradutor do desktop: desktop/src/main/erros-banco.js)
 */
function sb_mensagem_erro(SupabaseErro $e, array $mensagens = []): string
{
    $regra = sb_regra($e);

    if ($regra && isset($mensagens[$regra])) {
        return $mensagens[$regra];
    }

    return match ($e->codigo) {
        'P0001'                 => $e->getMessage(), // frase escrita por nós no banco, já em português
        '23505'                 => 'Já existe um cadastro com estes dados.',
        '23514', '23502'        => 'Algum campo não passou na conferência do banco. Confira os dados digitados.',
        '42501'                 => 'Você não tem permissão para fazer isso.',
        'sem_conexao', 'sem_curl' => $e->getMessage(),
        default                 => 'Não foi possível concluir. Tente de novo em instantes.',
    };
}
