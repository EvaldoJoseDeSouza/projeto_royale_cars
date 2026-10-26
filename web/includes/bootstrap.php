<?php
/*
| INICIALIZAÇÃO
*/

date_default_timezone_set('America/Sao_Paulo');

define('RAIZ', dirname(__DIR__));

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

header('X-Frame-Options: DENY');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: same-origin');

require RAIZ . '/includes/supabase.php';     
require RAIZ . '/includes/validacoes.php';
require RAIZ . '/includes/funcoes.php';
require RAIZ . '/includes/permissoes.php';
require RAIZ . '/includes/auth.php';
require RAIZ . '/includes/alertas.php';

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
