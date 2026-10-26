<?php

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/usuarios.php';

exigir_chefe();
exigir_post();

$usuario = buscar_colaborador((string) ($_POST['id'] ?? ''));

if (!$usuario) {
    flash('erro', 'Não é possível redefinir a senha deste usuário.');
    redirecionar('admin/usuarios.php');
}

[$resposta, $erro] = chamar_admin(['acao' => 'redefinir_senha', 'usuario_id' => $usuario['id']]);

if ($erro) {
    flash('erro', $erro);
} else {
    $_SESSION['senha_temporaria'] = ['nome' => $usuario['nome'], 'senha' => $resposta['senha_temporaria']];
    flash('sucesso', "Senha de {$usuario['nome']} redefinida.");
}

redirecionar('admin/usuarios.php');
