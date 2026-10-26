<?php
/*
| CONFIGURAÇÃO DO SUPABASE (modelo)
*/

return [
    // Endereço do projeto no Supabase (Settings → API → Project URL)
    'supabase_url' => 'https://saggupyjutibjruajwms.supabase.co',

    // Chave pública (Settings → API Keys → Publishable key)
    'supabase_chave' => 'sb_publishable_IfgXLkrumbCFJ_UswbOwyQ_JNaMKoDN',

    // Certificado SSL para o PHP confiar no site do Supabase.
    // Deixei null: o sistema procura sozinho o que vem com o XAMPP.
    // Só preencha se a página diagnostico.php mandar.
    'ca_bundle' => null,
];
