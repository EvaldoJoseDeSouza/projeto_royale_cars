<?php
/*
| Sair do sistema. Só aceita POST com token, para que um link
| malicioso não consiga deslogar o usuário.
*/

require __DIR__ . '/includes/bootstrap.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verificar_csrf();

    encerrar_sessao(); // também avisa o Supabase (ver includes/auth.php)
    flash('sucesso', 'Você saiu do sistema.');
}

redirecionar('index.php');
