<?php
/*
| Ativar ou desativar o acesso de um funcionário/gerente (Edge Function).
| Quem é desativado perde o acesso na hora, mesmo que esteja logado: o
| banco para de entregar os dados e o login fica bloqueado.
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/usuarios.php';

exigir_chefe();
exigir_post();

$usuario = buscar_colaborador((string) ($_POST['id'] ?? ''));
$ativar = (int) ($_POST['ativo'] ?? 0) === 1;

// buscar_colaborador nunca devolve o chefe: ninguém desativa o chefe por aqui
if (!$usuario) {
    flash('erro', 'Não é possível alterar o acesso deste usuário.');
    redirecionar('admin/usuarios.php');
}

[, $erro] = chamar_admin(['acao' => $ativar ? 'ativar' : 'desativar', 'usuario_id' => $usuario['id']]);

if ($erro) {
    flash('erro', $erro);
} else {
    flash('sucesso', $ativar
        ? "Acesso de {$usuario['nome']} reativado."
        : "Acesso de {$usuario['nome']} desativado. Ele não consegue mais entrar no sistema.");
}

redirecionar('admin/usuarios.php');
