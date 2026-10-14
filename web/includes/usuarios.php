<?php
/*
|--------------------------------------------------------------------------
| FUNÇÕES DO PAINEL ADMINISTRATIVO
|--------------------------------------------------------------------------
*/

/**
 * Senha temporária fácil de ditar: sem letras/números que confundem
 * (0/O, 1/l/I). Ex.: "Kp7m-Qx3t"
 */
function gerar_senha_temporaria(): string
{
    $letras = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ';
    $numeros = '23456789';

    $parte = function () use ($letras, $numeros): string {
        return $letras[random_int(0, strlen($letras) - 1)]
             . $letras[random_int(0, strlen($letras) - 1)]
             . $numeros[random_int(0, strlen($numeros) - 1)]
             . $letras[random_int(0, strlen($letras) - 1)];
    };

    return $parte() . '-' . $parte();
}

/** Troca todas as permissões do usuário pela lista nova. */
function salvar_permissoes(int $usuarioId, array $permissoes): void
{
    db_executar('DELETE FROM usuario_permissoes WHERE usuario_id = ?', [$usuarioId]);

    foreach ($permissoes as $permissao) {
        db_executar('INSERT INTO usuario_permissoes (usuario_id, permissao) VALUES (?, ?)', [$usuarioId, $permissao]);
    }
}

/** "liberou: X, Y; retirou: Z" */
function descrever_mudanca_permissoes(array $antes, array $depois): string
{
    $adicionadas = array_diff($depois, $antes);
    $removidas = array_diff($antes, $depois);
    $partes = [];

    if ($adicionadas) {
        $partes[] = 'liberou ' . implode(', ', array_map('nome_permissao', $adicionadas));
    }

    if ($removidas) {
        $partes[] = 'retirou ' . implode(', ', array_map('nome_permissao', $removidas));
    }

    return implode('; ', $partes);
}
