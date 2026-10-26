<?php
/*
| ALERTAS AUTOMÁTICOS
*/

const DIAS_AVISO_DEVOLUCAO = 2;  
const DIAS_AVISO_CNH       = 30;

const TIPOS_ALERTA = [
    'atraso' => [
        'titulo' => 'Aluguéis atrasados', 'etiqueta' => 'Atraso', 'cor' => 'status-vermelho',
        'ajuda'  => 'Entre em contato com o cliente. Cada dia de atraso é cobrado pela diária combinada.',
        'link'   => 'locacoes/ver.php?id=', 'botao' => 'Abrir', 'permissao' => 'locacoes_ver',
    ],
    'devolucao_proxima' => [
        'titulo' => 'Devoluções próximas', 'etiqueta' => 'Devolução', 'cor' => 'status-azul',
        'ajuda'  => 'Carros que voltam hoje ou nos próximos ' . DIAS_AVISO_DEVOLUCAO . ' dias.',
        'link'   => 'locacoes/ver.php?id=', 'botao' => 'Abrir', 'permissao' => 'locacoes_ver',
    ],
    'manutencao' => [
        'titulo' => 'Veículos em manutenção', 'etiqueta' => 'Oficina', 'cor' => 'status-laranja',
        'ajuda'  => 'Estes veículos estão bloqueados para aluguel.',
        'link'   => 'manutencoes/concluir.php?id=', 'botao' => 'Liberar', 'permissao' => 'manutencoes',
    ],
    'cnh' => [
        'titulo' => 'CNH vencida ou vencendo', 'etiqueta' => 'Documento', 'cor' => 'status-laranja',
        'ajuda'  => 'Clientes com CNH vencida não podem alugar.',
        'link'   => 'clientes/editar.php?id=', 'botao' => 'Atualizar', 'permissao' => 'clientes_gerenciar',
    ],
    'login_suspeito' => [
        'titulo' => 'Tentativas suspeitas de login (24h)', 'etiqueta' => 'Segurança', 'cor' => 'status-vermelho',
        'ajuda'  => 'Três ou mais senhas erradas do mesmo e-mail.',
        'link'   => 'admin/tentativas.php', 'botao' => 'Detalhes', 'permissao' => 'chefe',
    ],
];

function buscar_alertas(): array
{
    static $grupos = null;

    if ($grupos !== null) {
        return $grupos;
    }

    $grupos = array_fill_keys(array_keys(TIPOS_ALERTA), []);

    try {
        $lista = sb_select('vw_alertas', ['select' => 'tipo,referencia_id,titulo,detalhe,data', 'order' => 'data.asc']);
    } catch (SupabaseErro $e) {
        error_log('Não foi possível buscar os alertas: ' . $e->getMessage());
        $lista = []; 
    }

    foreach ($lista as $alerta) {
        if (isset($grupos[$alerta['tipo']])) {
            $grupos[$alerta['tipo']][] = $alerta;
        }
    }

    return $grupos;
}

function contar_alertas(): int
{
    return array_sum(array_map('count', buscar_alertas()));
}

function pode_abrir_alerta(string $tipo): bool
{
    $permissao = TIPOS_ALERTA[$tipo]['permissao'];

    return $permissao === 'chefe' ? eh_chefe() : pode($permissao);
}

function link_alerta(array $alerta): string
{
    $link = TIPOS_ALERTA[$alerta['tipo']]['link'];

    return str_ends_with($link, '=') ? $link . (int) $alerta['referencia_id'] : $link;
}
