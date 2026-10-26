<?php
/*
| FUNÇÕES DO PAINEL ADMINISTRATIVO 
*/

function chamar_admin(array $corpo): array
{
    try {
        $resposta = sb_funcao('admin-usuarios', $corpo);

        if (is_array($resposta) && isset($resposta['erro'])) {
            return [null, $resposta['erro']];
        }

        return [$resposta, null];
    } catch (SupabaseErro $e) {
        if ($e->codigo === 'sem_conexao') {
            return [null, 'Não foi possível falar com o servidor. Verifique a internet e tente de novo.'];
        }

        return [null, $e->status === 404
            ? 'A função admin-usuarios não está publicada no Supabase.'
            : $e->getMessage()];
    }
}

function listar_equipe(array $filtros = []): array
{
    $equipe = sb_select('perfis', $filtros + [
        'select' => 'id,nome,email,cargo,ativo,trocar_senha,ultimo_acesso,usuario_permissoes(permissao)',
        'order'  => 'ativo.desc,cargo.asc,nome.asc',
    ]);

    foreach ($equipe as &$pessoa) {
        $pessoa['permissoes'] = array_column($pessoa['usuario_permissoes'] ?? [], 'permissao');
        unset($pessoa['usuario_permissoes']);
    }
    unset($pessoa);

    return $equipe;
}

function buscar_colaborador(string $id): ?array
{
    if (!preg_match('/^[0-9a-f-]{36}$/', $id)) {
        return null;
    }

    $pessoa = listar_equipe(['id' => 'eq.' . $id])[0] ?? null;

    return $pessoa && $pessoa['cargo'] !== 'chefe' ? $pessoa : null;
}

function salvar_permissoes(string $usuarioId, array $antes, array $depois): void
{
    $tirar = array_values(array_diff($antes, $depois));
    $colocar = array_values(array_diff($depois, $antes));

    if ($tirar) {
        sb_apagar('usuario_permissoes', [
            'usuario_id' => 'eq.' . $usuarioId,
            'permissao'  => 'in.(' . implode(',', $tirar) . ')',
        ]);
    }

    if ($colocar) {
        sb_inserir('usuario_permissoes', array_map(fn ($p) => ['usuario_id' => $usuarioId, 'permissao' => $p], $colocar));
    }
}

function modelos_permissao(): array
{
    $modelos = [];

    foreach (sb_select('modelos_permissao', ['select' => 'nome,permissoes', 'order' => 'nome.asc']) as $m) {
        $modelos[$m['nome']] = $m['permissoes'];
    }

    return $modelos;
}
