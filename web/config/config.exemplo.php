<?php
/*
|--------------------------------------------------------------------------
| CONFIGURAÇÃO DO SUPABASE (modelo)
|--------------------------------------------------------------------------
| O sistema lê o arquivo config.local.php, se ele existir. Se não existir,
| usa este aqui. Então, para o projeto do grupo, não precisa fazer nada.
|
| Quando criar o config.local.php? Quando um computador precisar de algo
| diferente (outro projeto do Supabase, ou o caminho do certificado SSL).
| Copie este arquivo, renomeie para config.local.php e mude o que precisar.
| O config.local.php está no .gitignore: ele NUNCA vai para o GitHub.
|
| SEGURANÇA: aqui só pode entrar a chave PÚBLICA (publishable). Ela é a
| mesma que o desktop e o celular usam, e quem protege os dados são as
| regras do banco (RLS). A chave de serviço (service_role / secret) e a
| senha do banco NUNCA entram em arquivo nenhum do projeto.
*/

return [
    // Endereço do projeto no Supabase (Settings → API → Project URL)
    'supabase_url' => 'https://saggupyjutibjruajwms.supabase.co',

    // Chave pública (Settings → API Keys → Publishable key)
    'supabase_chave' => 'sb_publishable_IfgXLkrumbCFJ_UswbOwyQ_JNaMKoDN',

    // Certificado SSL para o PHP confiar no site do Supabase.
    // Deixe null: o sistema procura sozinho o que vem com o XAMPP.
    // Só preencha se a página diagnostico.php mandar.
    'ca_bundle' => null,
];
