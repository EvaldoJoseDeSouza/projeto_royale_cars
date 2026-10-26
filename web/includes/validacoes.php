<?php
/*
| VALIDAÇÕES DO LADO DO SERVIDOR
*/

function so_digitos(?string $valor): string
{
    return preg_replace('/\D/', '', (string) $valor);
}

function validar_cpf(string $cpf): bool
{
    $cpf = so_digitos($cpf);

    if (strlen($cpf) !== 11 || preg_match('/^(\d)\1{10}$/', $cpf)) {
        return false;
    }

    for ($posicao = 9; $posicao < 11; $posicao++) {
        $soma = 0;

        for ($i = 0; $i < $posicao; $i++) {
            $soma += (int) $cpf[$i] * (($posicao + 1) - $i);
        }

        $digito = ($soma * 10) % 11;

        if ($digito === 10) {
            $digito = 0;
        }

        if ((int) $cpf[$posicao] !== $digito) {
            return false;
        }
    }

    return true;
}

function validar_cnh(string $cnh): bool
{
    $cnh = so_digitos($cnh);

    if (strlen($cnh) !== 11 || preg_match('/^(\d)\1{10}$/', $cnh)) {
        return false;
    }

    $d = array_map('intval', str_split($cnh));

    $soma = 0;
    for ($i = 0, $peso = 9; $i < 9; $i++, $peso--) {
        $soma += $d[$i] * $peso;
    }

    $desconto = 0;
    $dv1 = $soma % 11;

    if ($dv1 >= 10) {
        $dv1 = 0;
        $desconto = 2;
    }

    $soma = 0;
    for ($i = 0, $peso = 1; $i < 9; $i++, $peso++) {
        $soma += $d[$i] * $peso;
    }

    $resto = $soma % 11;
    $dv2 = ($resto >= 10) ? 0 : $resto - $desconto;

    if ($dv1 === $d[9] && $dv2 === $d[10]) {
        return true;
    }

    $soma = 0;
    for ($i = 0; $i < 9; $i++) {
        $soma += $d[$i] * ($i + 2);
    }

    $resto = $soma % 11;
    $dv1 = ($resto <= 1) ? 0 : 11 - $resto;

    $numeros = array_merge([$dv1], array_slice($d, 0, 9));
    $soma = 0;
    foreach ($numeros as $i => $numero) {
        $soma += $numero * ($i + 2);
    }

    $resto = $soma % 11;
    $dv2 = ($resto <= 1) ? 0 : 11 - $resto;

    return $dv1 === $d[9] && $dv2 === $d[10];
}

function ddds_validos(): array
{
    return [
        11, 12, 13, 14, 15, 16, 17, 18, 19,
        21, 22, 24, 27, 28,
        31, 32, 33, 34, 35, 37, 38,
        41, 42, 43, 44, 45, 46, 47, 48, 49,
        51, 53, 54, 55,
        61, 62, 63, 64, 65, 66, 67, 68, 69,
        71, 73, 74, 75, 77, 79,
        81, 82, 83, 84, 85, 86, 87, 88, 89,
        91, 92, 93, 94, 95, 96, 97, 98, 99,
    ];
}

function validar_telefone(string $telefone): bool
{
    $telefone = so_digitos($telefone);

    if (!preg_match('/^\d{10,11}$/', $telefone)) {
        return false;
    }

    if (!in_array((int) substr($telefone, 0, 2), ddds_validos(), true)) {
        return false;
    }

    if (strlen($telefone) === 11) {
        return $telefone[2] === '9';
    }

    return in_array($telefone[2], ['2', '3', '4', '5'], true);
}

function validar_email(string $email): bool
{
    return strlen($email) <= 150
        && filter_var($email, FILTER_VALIDATE_EMAIL) !== false;
}

function validar_nome_completo(string $nome): bool
{
    $nome = trim(preg_replace('/\s+/', ' ', $nome));

    return mb_strlen($nome) >= 5
        && mb_strlen($nome) <= 150
        && preg_match("/^[\p{L}'.-]+(?: [\p{L}'.-]+)+$/u", $nome) === 1;
}

function normalizar_placa(string $placa): ?string
{
    $placa = strtoupper(preg_replace('/[\s-]/', '', $placa));

    if (preg_match('/^[A-Z]{3}\d{4}$/', $placa)) {
        return $placa; 
    }

    if (preg_match('/^[A-Z]{3}\d[A-Z]\d{2}$/', $placa)) {
        return $placa;
    }

    return null;
}

function normalizar_chassi(string $chassi): ?string
{
    $chassi = strtoupper(preg_replace('/\s/', '', $chassi));

    if (!preg_match('/^[A-HJ-NPR-Z0-9]{17}$/', $chassi)) {
        return null;
    }

    if (preg_match('/^(.)\1{16}$/', $chassi)) {
        return null;
    }

    return $chassi;
}

function validar_data(?string $data): bool
{
    if (!$data || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $data)) {
        return false;
    }

    [$ano, $mes, $dia] = array_map('intval', explode('-', $data));

    return checkdate($mes, $dia, $ano);
}

function ler_dinheiro(?string $valor): ?float
{
    $valor = trim((string) $valor);

    if ($valor === '') {
        return null;
    }

    if (str_contains($valor, ',')) {
        $valor = str_replace(['.', ','], ['', '.'], $valor);
    }

    if (!is_numeric($valor)) {
        return null;
    }

    return round((float) $valor, 2);
}

function validar_senha(string $senha): ?string
{
    if (strlen($senha) < 8) {
        return 'A senha deve ter pelo menos 8 caracteres.';
    }

    if (!preg_match('/[A-Za-z]/', $senha) || !preg_match('/\d/', $senha)) {
        return 'A senha deve ter letras e números.';
    }

    return null;
}
