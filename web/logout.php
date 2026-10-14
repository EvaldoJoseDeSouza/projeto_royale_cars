<?php
/*
| Sair do sistema. Só aceita POST com token, para que um link
| malicioso não consiga deslogar o usuário.
*/

require __DIR__ . '/includes/bootstrap.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verificar_csrf();

    if (usuario_logado()) {
        registrar_log('seguranca', 'logout', (int) $_SESSION['usuario_id'], 'Saiu do sistema.');
    }

    encerrar_sessao();
    flash('sucesso', 'Você saiu do sistema.');
}

redirecionar('index.php');
