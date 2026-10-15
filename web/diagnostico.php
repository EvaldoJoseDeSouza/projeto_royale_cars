<?php
/*
|--------------------------------------------------------------------------
| DIAGNÓSTICO DA LIGAÇÃO COM O SUPABASE
|--------------------------------------------------------------------------
| Abra http://localhost/<pasta-da-web>/diagnostico.php para conferir se este
| computador consegue falar com o Supabase. Não precisa de login e não
| mostra nenhum dado da locadora: só faz uma pergunta "inofensiva" ao banco.
|
| Não usa o bootstrap.php de propósito: assim funciona mesmo se o resto do
| sistema estiver com problema (é justamente quando mais precisamos dele).
*/

define('RAIZ', __DIR__);
require RAIZ . '/includes/supabase.php';

$verificacoes = [];

// 1. A extensão curl (o "navegador" do PHP) está ligada?
$temCurl = function_exists('curl_init');
$verificacoes[] = [
    'Extensão curl do PHP',
    $temCurl,
    $temCurl ? 'Ligada.' : 'Desligada. No XAMPP: Config (do Apache) → PHP (php.ini) → procure ";extension=curl", tire o ";" e reinicie o Apache.',
];

// 2. Qual configuração está valendo?
$arquivoConfig = is_file(RAIZ . '/config/config.local.php') ? 'config.local.php' : 'config.exemplo.php';
$config = sb_config();
$verificacoes[] = ['Configuração', true, "Usando config/$arquivoConfig → " . htmlspecialchars($config['supabase_url'])];

// 3. Certificado SSL encontrado?
$certificado = sb_certificado();
$verificacoes[] = [
    'Certificado SSL',
    true,
    $certificado ? 'Usando ' . htmlspecialchars($certificado) : 'Usando os certificados do sistema operacional.',
];

// 4. O teste de verdade: uma pergunta ao banco sem login.
//    login_bloqueado diz se um e-mail está bloqueado por senhas erradas
//    (é uma das poucas funções que o banco libera para quem não entrou).
if ($temCurl) {
    $inicio = microtime(true);
    try {
        sb_rpc('login_bloqueado', ['p_email' => 'diagnostico@royalecars.com.br'], false);
        $ms = round((microtime(true) - $inicio) * 1000);
        $verificacoes[] = ['Conversa com o Supabase', true, "Funcionou! O banco respondeu em {$ms} ms."];
    } catch (SupabaseErro $e) {
        $dica = $e->codigo === 'sem_conexao' && stripos($e->detalhes, 'certificate') !== false
            ? ' Dica: crie o config.local.php (copiando o config.exemplo.php) e preencha ca_bundle com o caminho do arquivo cacert.pem.'
            : '';
        $verificacoes[] = ['Conversa com o Supabase', false, htmlspecialchars($e->getMessage() . ' ' . $e->detalhes) . $dica];
    }
}

$tudoCerto = !in_array(false, array_column($verificacoes, 1), true);
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Diagnóstico · Royale Cars</title>
    <link rel="stylesheet" href="css/style.css">
    <style>
        .diagnostico { max-width: 720px; margin: 40px auto; padding: 0 16px; }
        .diagnostico table { width: 100%; border-collapse: collapse; background: #fff; }
        .diagnostico td { padding: 12px; border-bottom: 1px solid #e5e7eb; vertical-align: top; }
        .diagnostico td:first-child { font-weight: 600; width: 220px; }
        .ok { color: #15803d; font-weight: 700; }
        .falhou { color: #b91c1c; font-weight: 700; }
    </style>
</head>
<body>
<div class="diagnostico">
    <h1>Diagnóstico da ligação com o Supabase</h1>

    <div class="<?= $tudoCerto ? 'alert-success' : 'alert-error' ?>" style="margin: 16px 0;">
        <?= $tudoCerto ? 'Tudo certo: este computador consegue falar com o Supabase.' : 'Algo precisa ser ajustado. Veja abaixo.' ?>
    </div>

    <table>
        <?php foreach ($verificacoes as [$item, $passou, $texto]): ?>
            <tr>
                <td><?= $item ?></td>
                <td><span class="<?= $passou ? 'ok' : 'falhou' ?>"><?= $passou ? '✔ OK' : '✘ Problema' ?></span><br><?= $texto ?></td>
            </tr>
        <?php endforeach; ?>
    </table>
</div>
</body>
</html>
