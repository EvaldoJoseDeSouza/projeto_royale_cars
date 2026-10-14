<?php
/*
| Redefinir a senha de um funcionário/gerente.
| Gera uma senha temporária (mostrada uma única vez ao chefe) e obriga
| a pessoa a criar uma senha nova no próximo login.
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/usuarios.php';

exigir_chefe();
exigir_post();

$id = (int) ($_POST['id'] ?? 0);
$usuario = db_linha('SELECT id, nome, cargo FROM usuarios WHERE id = ?', [$id]);

if (!$usuario || $usuario['cargo'] === 'chefe') {
    flash('erro', 'Não é possível redefinir a senha deste usuário.');
    redirecionar('admin/usuarios.php');
}

$senha = gerar_senha_temporaria();

db_executar('UPDATE usuarios SET senha = ?, trocar_senha = 1 WHERE id = ?',
    [password_hash($senha, PASSWORD_DEFAULT), $id]);

// Libera o login caso a pessoa estivesse bloqueada por errar a senha
db_executar(
    'DELETE FROM login_tentativas WHERE sucesso = 0 AND email = (SELECT email FROM usuarios WHERE id = ?)
       AND criado_em > DATE_SUB(NOW(), INTERVAL ' . MINUTOS_BLOQUEIO . ' MINUTE)',
    [$id]
);

registrar_log('usuarios', 'redefinir_senha', $id, "Redefiniu a senha de {$usuario['nome']} (senha temporária gerada).");

$_SESSION['senha_temporaria'] = ['nome' => $usuario['nome'], 'senha' => $senha];
flash('sucesso', "Senha de {$usuario['nome']} redefinida.");

redirecionar('admin/usuarios.php');
