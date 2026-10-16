<?php
/*
|--------------------------------------------------------------------------
| FUNÇÕES DO PAINEL ADMINISTRATIVO (as mesmas regras do desktop)
|--------------------------------------------------------------------------
| Mexer em CONTAS DE LOGIN (criar, gerar senha, bloquear, trocar e-mail)
| precisa da chave de serviço do Supabase, que nunca pode ficar no PHP.
| Por isso essas ações vão para a Edge Function "admin-usuarios", que
| roda no servidor do Supabase e só obedece o chefe:
|
|   criar            → cria o login e o perfil, devolve a senha temporária
|   redefinir_senha  → gera senha temporária nova
|   ativar/desativar → libera ou bloqueia o login
|   alterar_email    → troca o e-mail de login
|
| Nome, cargo e permissões o chefe grava direto nas tabelas (o banco
| confere se é mesmo o chefe). O histórico é anotado pelo próprio banco.
*/

/**
 * Chama a Edge Function admin-usuarios.
 * Devolve [resposta, null] ou [null, mensagem de erro para a tela].
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
        // A função responde {"erro": "..."} com a frase pronta (ex.: "Já existe um usuário com este e-mail.")
        if ($e->codigo === 'sem_conexao') {
            return [null, 'Não foi possível falar com o servidor. Verifique a internet e tente de novo.'];
        }

        return [null, $e->status === 404
            ? 'A função admin-usuarios não está publicada no Supabase.'
            : $e->getMessage()];
    }
}

/** A equipe com as permissões de cada um "penduradas". */
function listar_equipe(array $filtros = []): array
{
    $equipe = sb_select('perfis', $filtros + [
        'select' => 'id,nome,email,cargo,ativo,trocar_senha,ultimo_acesso,usuario_permissoes(permissao)',
        // ativos primeiro; depois chefe, gerente, funcionário (a ordem do tipo cargo no banco); depois o nome
        'order'  => 'ativo.desc,cargo.asc,nome.asc',
    ]);

    foreach ($equipe as &$pessoa) {
        $pessoa['permissoes'] = array_column($pessoa['usuario_permissoes'] ?? [], 'permissao');
        unset($pessoa['usuario_permissoes']);
    }
    unset($pessoa);

    return $equipe;
}

/** Um colaborador (nunca o chefe) ou null. */
function buscar_colaborador(string $id): ?array
{
    if (!preg_match('/^[0-9a-f-]{36}$/', $id)) {
        return null;
    }

    $pessoa = listar_equipe(['id' => 'eq.' . $id])[0] ?? null;

    return $pessoa && $pessoa['cargo'] !== 'chefe' ? $pessoa : null;
}

/**
 * Troca as permissões da pessoa pela lista nova, mexendo SÓ no que mudou:
 * tira as desmarcadas e coloca as novas. Assim o histórico do banco
 * registra exatamente "liberou X" e "retirou Y" (igual ao desktop).
 */
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

/** Os modelos de permissão (Gerente, Vendedor...) criados no desktop: [nome => [permissões]]. */
function modelos_permissao(): array
{
    $modelos = [];

    foreach (sb_select('modelos_permissao', ['select' => 'nome,permissoes', 'order' => 'nome.asc']) as $m) {
        $modelos[$m['nome']] = $m['permissoes'];
    }

    return $modelos;
}
