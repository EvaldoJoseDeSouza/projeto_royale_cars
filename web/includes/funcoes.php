<?php
/*
|--------------------------------------------------------------------------
| FUNÇÕES DE APOIO
|--------------------------------------------------------------------------
| Funções usadas em várias páginas: banco de dados, segurança (CSRF),
| mensagens, formatação e histórico de ações.
*/


/* ========================================================================
   BANCO DE DADOS
   Todas as consultas usam "prepared statements": os valores vão separados
   do SQL, o que impede SQL Injection.
   ======================================================================== */

function db_consulta(string $sql, array $parametros = []): mysqli_stmt
{
    global $conexao;

    $stmt = $conexao->prepare($sql);

    if ($parametros) {
        $tipos = '';

        foreach ($parametros as $i => $valor) {
            if (is_bool($valor)) {
                $parametros[$i] = (int) $valor;
                $tipos .= 'i';
            } elseif (is_int($valor)) {
                $tipos .= 'i';
            } elseif (is_float($valor)) {
                $tipos .= 'd';
            } else {
                $tipos .= 's';
            }
        }

        $stmt->bind_param($tipos, ...$parametros);
    }

    $stmt->execute();

    return $stmt;
}

/** Devolve todas as linhas do resultado. */
function db_todos(string $sql, array $parametros = []): array
{
    $resultado = db_consulta($sql, $parametros)->get_result();

    return $resultado ? $resultado->fetch_all(MYSQLI_ASSOC) : [];
}

/** Devolve só a primeira linha (ou null). */
function db_linha(string $sql, array $parametros = []): ?array
{
    $resultado = db_consulta($sql, $parametros)->get_result();
    $linha = $resultado ? $resultado->fetch_assoc() : null;

    return $linha ?: null;
}

/** Devolve o primeiro valor da primeira linha. */
function db_valor(string $sql, array $parametros = [])
{
    $linha = db_linha($sql, $parametros);

    return $linha ? reset($linha) : null;
}

/** Executa INSERT/UPDATE/DELETE e devolve quantas linhas mudaram. */
function db_executar(string $sql, array $parametros = []): int
{
    return db_consulta($sql, $parametros)->affected_rows;
}

function db_ultimo_id(): int
{
    global $conexao;

    return (int) $conexao->insert_id;
}

/**
 * Quando o banco recusa um valor repetido (UNIQUE), descobre qual campo foi.
 * Ex.: "uk_clientes_cpf" → "cpf".
 */
function campo_duplicado(mysqli_sql_exception $erro): ?string
{
    if ($erro->getCode() !== 1062) {
        return null;
    }

    if (preg_match("/key '(?:[^.']*\.)?uk_[a-z]+_([a-z_]+)'/i", $erro->getMessage(), $m)) {
        return $m[1];
    }

    return 'registro';
}

/** O banco recusou por uma regra CHECK (MariaDB 4025 / MySQL 3819). */
function violou_regra_banco(mysqli_sql_exception $erro): bool
{
    return in_array($erro->getCode(), [4025, 3819], true);
}


/* ========================================================================
   ENDEREÇOS E REDIRECIONAMENTO
   ======================================================================== */

/** Monta um link a partir da raiz do sistema. Ex.: url('clientes/index.php') */
function url(string $caminho = ''): string
{
    return BASE_URL . '/' . ltrim($caminho, '/');
}

function redirecionar(string $caminho): void
{
    header('Location: ' . url($caminho));
    exit;
}

/** Escapa texto para mostrar no HTML (evita XSS). */
function e($texto): string
{
    return htmlspecialchars((string) $texto, ENT_QUOTES, 'UTF-8');
}

function ip_cliente(): string
{
    return substr($_SERVER['REMOTE_ADDR'] ?? '0.0.0.0', 0, 45);
}


/* ========================================================================
   PROTEÇÃO CSRF
   Cada formulário leva um código secreto da sessão. Se outro site tentar
   enviar um formulário em nome do usuário, o código não bate e a ação
   é recusada.
   ======================================================================== */

function csrf_token(): string
{
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(32));
    }

    return $_SESSION['csrf'];
}

function csrf_campo(): string
{
    return '<input type="hidden" name="csrf" value="' . e(csrf_token()) . '">';
}

function verificar_csrf(): void
{
    $enviado = $_POST['csrf'] ?? '';

    if (!is_string($enviado) || !hash_equals(csrf_token(), $enviado)) {
        registrar_log('seguranca', 'csrf_invalido', null,
            'Formulário recusado por token de segurança inválido em ' . ($_SERVER['SCRIPT_NAME'] ?? '?') . '.');

        http_response_code(400);
        die('Sessão expirada ou formulário inválido. Volte, recarregue a página e tente de novo.');
    }
}

/** Ações que mudam dados (arquivar, finalizar...) só aceitam POST + CSRF. */
function exigir_post(): void
{
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        die('Ação não permitida.');
    }

    verificar_csrf();
}

/** Formulário de um botão só, para ações como Arquivar ou Reativar. */
function botao_acao(string $acao, array $campos, string $texto, string $classe = 'btn-small', string $confirmar = ''): string
{
    $html = '<form method="POST" action="' . e(url($acao)) . '" class="form-inline"';

    if ($confirmar !== '') {
        $html .= ' data-confirmar="' . e($confirmar) . '"';
    }

    $html .= '>' . csrf_campo();

    foreach ($campos as $nome => $valor) {
        $html .= '<input type="hidden" name="' . e($nome) . '" value="' . e($valor) . '">';
    }

    return $html . '<button type="submit" class="' . e($classe) . '">' . e($texto) . '</button></form>';
}


/* ========================================================================
   MENSAGENS (aparecem uma vez na próxima página)
   ======================================================================== */

function flash(string $tipo, string $mensagem): void
{
    $_SESSION['flash'][] = ['tipo' => $tipo, 'mensagem' => $mensagem];
}

function mostrar_flash(): string
{
    $html = '';

    foreach ($_SESSION['flash'] ?? [] as $item) {
        $classe = $item['tipo'] === 'sucesso' ? 'alert-success' : ($item['tipo'] === 'aviso' ? 'alert-warning' : 'alert-error');
        $html .= '<div class="' . $classe . '">' . e($item['mensagem']) . '</div>';
    }

    unset($_SESSION['flash']);

    return $html;
}

/** Mostra a lista de erros de validação de um formulário. */
function mostrar_erros(array $erros): string
{
    if (!$erros) {
        return '';
    }

    $html = '<div class="alert-error"><strong>Corrija os campos abaixo:</strong><ul>';

    foreach ($erros as $erro) {
        $html .= '<li>' . e($erro) . '</li>';
    }

    return $html . '</ul></div>';
}

/** Erro de um campo específico, embaixo do input. */
function erro_campo(array $erros, string $campo): string
{
    return isset($erros[$campo]) ? '<small class="campo-erro">' . e($erros[$campo]) . '</small>' : '';
}

function classe_erro(array $erros, string $campo): string
{
    return isset($erros[$campo]) ? ' invalido' : '';
}


/* ========================================================================
   FORMATAÇÃO
   ======================================================================== */

function moeda($valor): string
{
    return 'R$ ' . number_format((float) $valor, 2, ',', '.');
}

function data_br(?string $data): string
{
    return $data ? date('d/m/Y', strtotime($data)) : '—';
}

function data_hora_br(?string $data): string
{
    return $data ? date('d/m/Y H:i', strtotime($data)) : '—';
}

function formatar_cpf(?string $cpf): string
{
    $cpf = so_digitos($cpf);

    return strlen($cpf) === 11
        ? substr($cpf, 0, 3) . '.' . substr($cpf, 3, 3) . '.' . substr($cpf, 6, 3) . '-' . substr($cpf, 9)
        : (string) $cpf;
}

function formatar_telefone(?string $telefone): string
{
    $t = so_digitos($telefone);

    if (strlen($t) === 11) {
        return '(' . substr($t, 0, 2) . ') ' . substr($t, 2, 5) . '-' . substr($t, 7);
    }

    if (strlen($t) === 10) {
        return '(' . substr($t, 0, 2) . ') ' . substr($t, 2, 4) . '-' . substr($t, 6);
    }

    return (string) $telefone;
}

/** Placa antiga aparece com hífen (ABC-1234); Mercosul sem (ABC1D23). */
function formatar_placa(?string $placa): string
{
    $placa = (string) $placa;

    return preg_match('/^[A-Z]{3}\d{4}$/', $placa)
        ? substr($placa, 0, 3) . '-' . substr($placa, 3)
        : $placa;
}

function nome_veiculo(array $v): string
{
    return trim(($v['marca'] ?? '') . ' ' . ($v['modelo'] ?? ''));
}

/** Etiqueta colorida de status. */
function badge_status(string $status): string
{
    $classes = [
        'Disponível'    => 'status-verde',
        'Finalizada'    => 'status-verde',
        'Concluída'     => 'status-verde',
        'Ativo'         => 'status-verde',
        'Alugado'       => 'status-azul',
        'Em andamento'  => 'status-azul',
        'Em manutenção' => 'status-laranja',
        'Atrasada'      => 'status-vermelho',
        'Cancelada'     => 'status-cinza',
        'Inativo'       => 'status-cinza',
        'Arquivado'     => 'status-cinza',
    ];

    return '<span class="status ' . ($classes[$status] ?? 'status-cinza') . '">' . e($status) . '</span>';
}

/** Status da locação levando em conta o atraso. */
function status_locacao(array $locacao): string
{
    if ($locacao['status'] === 'Em andamento' && $locacao['data_prevista'] < date('Y-m-d')) {
        return 'Atrasada';
    }

    return $locacao['status'];
}

function dias_entre(string $inicio, string $fim): int
{
    return (int) (new DateTime($inicio))->diff(new DateTime($fim))->format('%r%a');
}

/** Nome do mês abreviado em português. */
function mes_abreviado(int $mes): string
{
    return ['', 'jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'][$mes];
}


/* ========================================================================
   HISTÓRICO DE AÇÕES
   Toda ação importante grava quem fez, o quê, quando e de qual IP.
   ======================================================================== */

function registrar_log(string $modulo, string $acao, ?int $registroId, string $descricao): void
{
    try {
        db_executar(
            'INSERT INTO logs (usuario_id, modulo, acao, registro_id, descricao, ip)
             VALUES (?, ?, ?, ?, ?, ?)',
            [$_SESSION['usuario_id'] ?? null, $modulo, $acao, $registroId, $descricao, ip_cliente()]
        );
    } catch (mysqli_sql_exception $e) {
        // O histórico nunca pode travar o sistema.
        error_log('Falha ao gravar log: ' . $e->getMessage());
    }
}

/** Valor enviado no formulário (para manter o que foi digitado após um erro). */
function campo(array $dados, string $nome, string $padrao = ''): string
{
    return e($dados[$nome] ?? $padrao);
}

/** Paginação simples. Devolve [limite, offset, pagina, totalPaginas]. */
function paginar(int $total, int $porPagina = 20): array
{
    $totalPaginas = max(1, (int) ceil($total / $porPagina));
    $pagina = min($totalPaginas, max(1, (int) ($_GET['pagina'] ?? 1)));

    return [$porPagina, ($pagina - 1) * $porPagina, $pagina, $totalPaginas];
}

function links_paginacao(int $pagina, int $totalPaginas): string
{
    if ($totalPaginas <= 1) {
        return '';
    }

    $html = '<nav class="paginacao">';

    for ($p = 1; $p <= $totalPaginas; $p++) {
        $query = http_build_query(array_merge($_GET, ['pagina' => $p]));
        $classe = $p === $pagina ? ' class="ativa"' : '';
        $html .= '<a href="?' . e($query) . '"' . $classe . '>' . $p . '</a>';
    }

    return $html . '</nav>';
}


/* ========================================================================
   ÍCONES (desenhos em SVG, funcionam sem internet)
   ======================================================================== */

function icone(string $nome): string
{
    $desenhos = [
        'inicio'     => '<path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.5V21h14V9.5"/>',
        'alerta'     => '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
        'clientes'   => '<circle cx="9" cy="7" r="4"/><path d="M3 21v-2a4 4 0 0 1 4-4h4a4 4 0 0 1 4 4v2"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/><path d="M21 21v-2a4 4 0 0 0-3-3.85"/>',
        'veiculos'   => '<path d="M5 17H3v-5l2-5h14l2 5v5h-2"/><circle cx="7.5" cy="17" r="2"/><circle cx="16.5" cy="17" r="2"/><path d="M9.5 17h5"/><path d="M3 12h18"/>',
        'locacoes'   => '<circle cx="7.5" cy="15.5" r="4.5"/><path d="M10.7 12.3 21 2"/><path d="m16 7 3 3"/><path d="m19 4 2 2"/>',
        'manutencao' => '<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>',
        'financeiro' => '<rect x="2" y="6" width="20" height="12" rx="2"/><circle cx="12" cy="12" r="2.5"/><path d="M6 12h.01M18 12h.01"/>',
        'relatorios' => '<path d="M3 3v18h18"/><path d="M7 16v-5"/><path d="M12 16V7"/><path d="M17 16v-3"/>',
        'admin'      => '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>',
        'conta'      => '<circle cx="12" cy="8" r="4"/><path d="M4 21v-1a6 6 0 0 1 6-6h4a6 6 0 0 1 6 6v1"/>',
        'sair'       => '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="m16 17 5-5-5-5"/><path d="M21 12H9"/>',
    ];

    return '<svg class="icone" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" '
         . 'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
         . ($desenhos[$nome] ?? '') . '</svg>';
}
