<?php
/*
|--------------------------------------------------------------------------
| HISTÓRICO DE AÇÕES (exclusivo do chefe)
|--------------------------------------------------------------------------
| Quem cadastrou um cliente, mudou o preço de um carro, arquivou um
| cadastro, finalizou um aluguel... com data, hora e IP.
| O histórico não pode ser editado nem apagado pelo sistema.
*/

require __DIR__ . '/../includes/bootstrap.php';

exigir_chefe();

$modulos = [
    'clientes'    => 'Clientes',
    'veiculos'    => 'Veículos',
    'locacoes'    => 'Aluguéis',
    'manutencoes' => 'Manutenção',
    'usuarios'    => 'Usuários',
    'relatorios'  => 'Relatórios',
    'seguranca'   => 'Segurança e acessos',
];

$f = [
    'usuario_id' => (int) ($_GET['usuario_id'] ?? 0),
    'modulo'     => isset($modulos[$_GET['modulo'] ?? '']) ? $_GET['modulo'] : '',
    'de'         => validar_data($_GET['de'] ?? '') ? $_GET['de'] : '',
    'ate'        => validar_data($_GET['ate'] ?? '') ? $_GET['ate'] : '',
    'busca'      => trim((string) ($_GET['busca'] ?? '')),
];

$where = ['1 = 1'];
$p = [];

if ($f['usuario_id']) { $where[] = 'l.usuario_id = ?'; $p[] = $f['usuario_id']; }
if ($f['modulo']) { $where[] = 'l.modulo = ?'; $p[] = $f['modulo']; }
if ($f['de']) { $where[] = 'l.criado_em >= ?'; $p[] = $f['de'] . ' 00:00:00'; }
if ($f['ate']) { $where[] = 'l.criado_em <= ?'; $p[] = $f['ate'] . ' 23:59:59'; }
if ($f['busca'] !== '') { $where[] = 'l.descricao LIKE ?'; $p[] = '%' . $f['busca'] . '%'; }

$sqlWhere = implode(' AND ', $where);

$total = (int) db_valor("SELECT COUNT(*) FROM logs l WHERE {$sqlWhere}", $p);
[$limite, $offset, $pagina, $totalPaginas] = paginar($total, 30);

$registros = db_todos(
    "SELECT l.*, u.nome AS usuario, u.cargo
     FROM logs l
     LEFT JOIN usuarios u ON u.id = l.usuario_id
     WHERE {$sqlWhere}
     ORDER BY l.id DESC
     LIMIT {$limite} OFFSET {$offset}",
    $p
);

$usuarios = db_todos('SELECT id, nome FROM usuarios ORDER BY nome');

$nomesAcoes = [
    'cadastrar' => 'Cadastro', 'editar' => 'Edição', 'arquivar' => 'Arquivamento', 'reativar' => 'Reativação',
    'finalizar' => 'Devolução', 'cancelar' => 'Cancelamento', 'abrir' => 'Envio à oficina', 'concluir' => 'Liberação',
    'ativar' => 'Ativação', 'desativar' => 'Desativação', 'redefinir_senha' => 'Senha redefinida', 'alterar_senha' => 'Troca de senha',
    'login' => 'Entrada', 'logout' => 'Saída', 'login_bloqueado' => 'Login bloqueado', 'login_desativado' => 'Login de desativado',
    'acesso_negado' => 'Acesso negado', 'csrf_invalido' => 'Formulário inválido', 'exportar' => 'Exportação',
];

$alertaAcoes = ['login_bloqueado', 'login_desativado', 'acesso_negado', 'csrf_invalido'];

$titulo = 'Histórico de ações';
$subtitulo = 'Painel Administrativo';
$menu = 'admin';
require RAIZ . '/includes/cabecalho.php';
?>

<div class="page-header">
    <div>
        <h2>Tudo o que foi feito no sistema</h2>
        <p><?= $total ?> registro(s) encontrado(s).</p>
    </div>
    <div class="acoes-topo">
        <a href="<?= e(url('admin/index.php')) ?>" class="btn-secondary">Voltar ao painel</a>
        <a href="<?= e(url('admin/tentativas.php')) ?>" class="btn-secondary">Tentativas de login</a>
    </div>
</div>

<form method="GET" class="filtros">
    <div class="filtro">
        <label for="usuario_id">Usuário</label>
        <select id="usuario_id" name="usuario_id">
            <option value="">Todos</option>
            <?php foreach ($usuarios as $u): ?>
                <option value="<?= $u['id'] ?>" <?= $f['usuario_id'] === (int) $u['id'] ? 'selected' : '' ?>><?= e($u['nome']) ?></option>
            <?php endforeach; ?>
        </select>
    </div>
    <div class="filtro">
        <label for="modulo">Área</label>
        <select id="modulo" name="modulo">
            <option value="">Todas</option>
            <?php foreach ($modulos as $chave => $nome): ?>
                <option value="<?= e($chave) ?>" <?= $f['modulo'] === $chave ? 'selected' : '' ?>><?= e($nome) ?></option>
            <?php endforeach; ?>
        </select>
    </div>
    <div class="filtro">
        <label for="de">De</label>
        <input type="date" id="de" name="de" value="<?= e($f['de']) ?>">
    </div>
    <div class="filtro">
        <label for="ate">Até</label>
        <input type="date" id="ate" name="ate" value="<?= e($f['ate']) ?>">
    </div>
    <div class="filtro largo">
        <label for="busca">Texto</label>
        <input type="text" id="busca" name="busca" value="<?= e($f['busca']) ?>" placeholder="Ex.: diária, Porsche, CPF...">
    </div>
    <button type="submit" class="btn-primary">Filtrar</button>
</form>

<div class="table-container">
    <table>
        <thead>
            <tr>
                <th>Data e hora</th>
                <th>Usuário</th>
                <th>Área</th>
                <th>Ação</th>
                <th>Descrição</th>
                <th>IP</th>
            </tr>
        </thead>
        <tbody>
            <?php foreach ($registros as $r): ?>
                <tr class="<?= in_array($r['acao'], $alertaAcoes, true) ? 'linha-alerta' : '' ?>">
                    <td style="white-space: nowrap;"><?= data_hora_br($r['criado_em']) ?></td>
                    <td>
                        <?= e($r['usuario'] ?? '—') ?>
                        <?php if ($r['cargo']): ?><br><small class="texto-fraco"><?= e(CARGOS[$r['cargo']]) ?></small><?php endif; ?>
                    </td>
                    <td><?= e($modulos[$r['modulo']] ?? $r['modulo']) ?></td>
                    <td><?= e($nomesAcoes[$r['acao']] ?? $r['acao']) ?></td>
                    <td><?= e($r['descricao']) ?></td>
                    <td class="texto-fraco"><?= e($r['ip']) ?></td>
                </tr>
            <?php endforeach; ?>

            <?php if (!$registros): ?>
                <tr><td colspan="6" class="empty">Nenhuma ação encontrada com esses filtros.</td></tr>
            <?php endif; ?>
        </tbody>
    </table>
</div>

<?= links_paginacao($pagina, $totalPaginas) ?>

<?php require RAIZ . '/includes/rodape.php'; ?>
