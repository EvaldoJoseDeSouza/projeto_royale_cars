<?php
/*
|--------------------------------------------------------------------------
| INICIALIZAÇÃO
|--------------------------------------------------------------------------
| Toda página começa com:  require __DIR__ . '/../includes/bootstrap.php';
| Isso abre a sessão, conecta ao banco e carrega as funções do sistema.
*/

date_default_timezone_set('America/Sao_Paulo');

define('RAIZ', dirname(__DIR__));

// Sessão mais segura: o cookie não pode ser lido por JavaScript
if (session_status() === PHP_SESSION_NONE) {
    session_name('ROYALECARS');
    session_set_cookie_params([
        'lifetime' => 0,
        'path'     => '/',
        'httponly' => true,
        'samesite' => 'Lax',
        'secure'   => !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off',
    ]);
    ini_set('session.use_strict_mode', '1');
    session_start();
}

// Cabeçalhos de segurança do navegador
header('X-Frame-Options: DENY');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: same-origin');

require RAIZ . '/config/database.php';
require RAIZ . '/includes/validacoes.php';
require RAIZ . '/includes/funcoes.php';
require RAIZ . '/includes/permissoes.php';
require RAIZ . '/includes/auth.php';
require RAIZ . '/includes/alertas.php';


/*
| Endereço base do sistema (ex.: "/royale-cars-web").
| É calculado sozinho, então o sistema funciona em qualquer pasta do htdocs.
*/
function calcular_base_url(): string
{
    $raiz   = str_replace('\\', '/', realpath(RAIZ));
    $script = str_replace('\\', '/', realpath($_SERVER['SCRIPT_FILENAME'] ?? '') ?: '');
    $nome   = $_SERVER['SCRIPT_NAME'] ?? '';

    if ($raiz && $script && stripos($script, $raiz) === 0) {
        $relativo = substr($script, strlen($raiz)); // ex.: /clientes/index.php

        if (strcasecmp(substr($nome, -strlen($relativo)), $relativo) === 0) {
            return rtrim(substr($nome, 0, -strlen($relativo)), '/');
        }
    }

    return '';
}

define('BASE_URL', calcular_base_url());
