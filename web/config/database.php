<?php
/*
|--------------------------------------------------------------------------
| CONEXÃO COM O BANCO DE DADOS
|--------------------------------------------------------------------------
| Ajuste os dados abaixo se o seu MySQL tiver outro usuário ou senha.
*/

$host    = 'localhost';
$usuario = 'root';
$senha   = '';
$banco   = 'royale_cars';

/*
| Faz o mysqli lançar exceções em caso de erro. Assim conseguimos usar
| try/catch e transações (tudo ou nada) nas operações importantes.
*/
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

try {
    $conexao = new mysqli($host, $usuario, $senha, $banco);
    $conexao->set_charset('utf8mb4');

    // Mesmo fuso horário do PHP (horário de Brasília)
    $conexao->query("SET time_zone = '-03:00'");
} catch (mysqli_sql_exception $e) {
    error_log('Erro de conexão: ' . $e->getMessage());
    http_response_code(500);
    die('Não foi possível conectar ao banco de dados. Verifique se o MySQL está ligado no XAMPP.');
}
