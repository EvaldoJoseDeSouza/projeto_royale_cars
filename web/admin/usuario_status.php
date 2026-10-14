<?php
/*
| Ativar ou desativar o acesso de um funcionário/gerente.
| Quem é desativado perde o acesso na hora (mesmo que esteja logado).
*/

require __DIR__ . '/../includes/bootstrap.php';

exigir_chefe();
exigir_post();

$id = (int) ($_POST['id'] ?? 0);
$ativo = (int) ($_POST['ativo'] ?? 0) === 1 ? 1 : 0;

$usuario = db_linha('SELECT id, nome, cargo FROM usuarios WHERE id = ?', [$id]);

if (!$usuario || $usuario['cargo'] === 'chefe' || $id === (int) $_SESSION['usuario_id']) {
    flash('erro', 'Não é possível alterar o acesso deste usuário.');
    redirecionar('admin/usuarios.php');
}

db_executar('UPDATE usuarios SET ativo = ? WHERE id = ?', [$ativo, $id]);

registrar_log('usuarios', $ativo ? 'ativar' : 'desativar', $id,
    ($ativo ? 'Reativou' : 'Desativou') . " o acesso de {$usuario['nome']}.");

flash('sucesso', $ativo
    ? "Acesso de {$usuario['nome']} reativado."
    : "Acesso de {$usuario['nome']} desativado. Ele não consegue mais entrar no sistema.");

redirecionar('admin/usuarios.php');
