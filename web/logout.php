<?php

require __DIR__ . '/includes/bootstrap.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verificar_csrf();

    encerrar_sessao(); 
    flash('sucesso', 'Você saiu do sistema.');
}

redirecionar('index.php');
