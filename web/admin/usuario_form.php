<?php
/*
|--------------------------------------------------------------------------
| CADASTRAR / EDITAR FUNCIONÁRIO OU GERENTE (exclusivo do chefe)
|--------------------------------------------------------------------------
| Cadastrar: tudo pela Edge Function (ela cria o login, o perfil e as
| permissões, e devolve a senha temporária, que aparece uma única vez).
| No primeiro login a pessoa é obrigada a criar a própria senha.
|
| Editar (igual ao desktop):
|  1) e-mail mudou → Edge Function (mexe no login);
|  2) nome e cargo → direto na tabela perfis (o banco confere se é o chefe);
|  3) permissões   → tira as desmarcadas, coloca as novas.
*/

require __DIR__ . '/../includes/bootstrap.php';
require RAIZ . '/includes/usuarios.php';

exigir_chefe();

$id = (string) ($_GET['id'] ?? '');
$editando = $id !== '';
$erros = [];

if ($editando) {
    $usuario = buscar_colaborador($id);

    if (!$usuario) {
        flash('erro', 'Usuário não encontrado. (Os dados do chefe são alterados em "Minha conta".)');
        redirecionar('admin/usuarios.php');
    }

    $dados = $usuario;
} else {
    $dados = ['nome' => '', 'email' => '', 'cargo' => 'funcionario', 'permissoes' => []];
}

$modelos = modelos_permissao();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verificar_csrf();

    $dados['nome'] = trim(preg_replace('/\s+/', ' ', (string) ($_POST['nome'] ?? '')));
    $dados['email'] = mb_strtolower(trim((string) ($_POST['email'] ?? '')));
    $dados['cargo'] = (string) ($_POST['cargo'] ?? '');
    $dados['permissoes'] = limpar_permissoes((array) ($_POST['permissoes'] ?? []));

    if (!validar_nome_completo($dados['nome'])) {
        $erros['nome'] = 'Informe nome e sobrenome.';
    }

    if (!validar_email($dados['email'])) {
        $erros['email'] = 'Digite um e-mail válido.';
    }

    // O cargo de chefe não pode ser dado por aqui (o banco também barra)
    if (!in_array($dados['cargo'], ['gerente', 'funcionario'], true)) {
        $erros['cargo'] = 'Escolha o cargo.';
    }

    if (!$dados['permissoes']) {
        $erros['permissoes'] = 'Marque pelo menos uma permissão (ou escolha um modelo).';
    }

    if (!$erros && !$editando) {
        [$criado, $erro] = chamar_admin([
            'acao'       => 'criar',
            'nome'       => $dados['nome'],
            'email'      => $dados['email'],
            'cargo'      => $dados['cargo'],
            'permissoes' => $dados['permissoes'],
        ]);

        if ($erro) {
            $erros[str_contains($erro, 'e-mail') ? 'email' : 'geral'] = $erro;
        } else {
            // A senha aparece uma única vez, na lista (depois some da sessão)
            $_SESSION['senha_temporaria'] = ['nome' => $dados['nome'], 'senha' => $criado['senha_temporaria']];
            flash('sucesso', "{$dados['nome']} cadastrado(a). Login: {$dados['email']}");
            redirecionar('admin/usuarios.php');
        }
    }

    if (!$erros && $editando) {
        // 1) E-mail de login (mexe no Supabase Auth: Edge Function)
        if ($dados['email'] !== $usuario['email']) {
            [, $erro] = chamar_admin(['acao' => 'alterar_email', 'usuario_id' => $id, 'email' => $dados['email']]);

            if ($erro) {
                $erros['email'] = $erro;
            }
        }

        if (!$erros) {
            try {
                // 2) Nome e cargo  3) Permissões (o banco anota tudo no histórico)
                sb_atualizar('perfis', ['id' => 'eq.' . $id], ['nome' => $dados['nome'], 'cargo' => $dados['cargo']]);
                salvar_permissoes($id, $usuario['permissoes'], $dados['permissoes']);

                flash('sucesso', "Acesso de {$dados['nome']} atualizado. As mudanças valem a partir da próxima página que ele abrir.");
                redirecionar('admin/usuarios.php');
            } catch (SupabaseErro $e) {
                $erros['geral'] = sb_mensagem_erro($e);
            }
        }
    }
}

$titulo = $editando ? 'Editar acesso' : 'Cadastrar funcionário';
$subtitulo = $editando ? $usuario['nome'] : 'Novo login individual';
$menu = 'admin';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="form-container">
    <div class="page-header">
        <div>
            <h2><?= $editando ? 'Dados e permissões' : 'Novo funcionário ou gerente' ?></h2>
            <p>
                <?= $editando
                    ? 'Para bloquear ou trocar a senha, use os botões na lista de funcionários.'
                    : 'Uma senha temporária será gerada. A pessoa cria a própria senha no primeiro acesso.' ?>
            </p>
        </div>
        <a href="<?= e(url('admin/usuarios.php')) ?>" class="btn-secondary">Voltar</a>
    </div>

    <?= $erros ? mostrar_erros(array_unique(array_values($erros))) : '' ?>

    <form method="POST" novalidate>
        <?= csrf_campo() ?>

        <div class="form-grid form-grid-3">
            <div class="form-group">
                <label for="nome">Nome completo *</label>
                <input type="text" id="nome" name="nome" value="<?= campo($dados, 'nome') ?>" maxlength="100"
                       data-validar="nome" class="<?= classe_erro($erros, 'nome') ?>" required>
                <?= erro_campo($erros, 'nome') ?>
            </div>

            <div class="form-group">
                <label for="email">E-mail (login) *</label>
                <input type="email" id="email" name="email" value="<?= campo($dados, 'email') ?>" maxlength="150"
                       data-validar="email" class="<?= classe_erro($erros, 'email') ?>" required>
                <?= erro_campo($erros, 'email') ?>
            </div>

            <div class="form-group">
                <label for="cargo">Cargo *</label>
                <select id="cargo" name="cargo" class="<?= classe_erro($erros, 'cargo') ?>" required>
                    <option value="funcionario" <?= $dados['cargo'] === 'funcionario' ? 'selected' : '' ?>>Funcionário</option>
                    <option value="gerente" <?= $dados['cargo'] === 'gerente' ? 'selected' : '' ?>>Gerente</option>
                </select>
                <?= erro_campo($erros, 'cargo') ?>
            </div>
        </div>

        <h3 class="secao-form">Permissões</h3>

        <p class="texto-fraco" style="margin-bottom: 12px;">
            Marque o que esta pessoa pode fazer, ou comece por um modelo:
            <select data-aplicar-modelo aria-label="Usar modelo de permissões">
                <option value="">Usar modelo...</option>
                <?php foreach (array_keys($modelos) as $nomeModelo): ?>
                    <option value="<?= e($nomeModelo) ?>"><?= e($nomeModelo) ?> (<?= count($modelos[$nomeModelo]) ?> permissões)</option>
                <?php endforeach; ?>
            </select>
        </p>

        <?= erro_campo($erros, 'permissoes') ?>

        <div class="permissoes-grupos" data-permissoes
             data-modelos="<?= e(json_encode($modelos)) ?>"
             data-dependencias="<?= e(json_encode(PERMISSOES_DEPENDENTES)) ?>">
            <?php foreach (PERMISSOES as $grupo => $lista): ?>
                <div class="permissoes-grupo">
                    <h4><?= e($grupo) ?></h4>
                    <?php foreach ($lista as $chave => $texto): ?>
                        <label class="checkbox">
                            <input type="checkbox" name="permissoes[]" value="<?= e($chave) ?>"
                                <?= in_array($chave, $dados['permissoes'], true) ? 'checked' : '' ?>>
                            <?= e($texto) ?>
                        </label>
                    <?php endforeach; ?>
                </div>
            <?php endforeach; ?>

            <div class="permissoes-grupo" style="background: #f8f9fc;">
                <h4>Somente o chefe</h4>
                <p class="texto-fraco">Administração: cadastrar pessoas, mudar permissões, redefinir senhas e ver o histórico de ações.</p>
            </div>
        </div>

        <div class="form-actions">
            <button type="submit" class="btn-primary"><?= $editando ? 'Salvar alterações' : 'Cadastrar e gerar senha' ?></button>
            <a href="<?= e(url('admin/usuarios.php')) ?>" class="btn-secondary">Cancelar</a>
        </div>
    </form>
</div>

<?php require RAIZ . '/includes/rodape.php'; ?>
