<?php
/*
|--------------------------------------------------------------------------
| ALERTAS AUTOMÁTICOS
|--------------------------------------------------------------------------
| Vêm prontos da visão vw_alertas do banco — a MESMA que o desktop e o
| celular usam, então o número de alertas é igual nas 3 plataformas:
|   atraso             aluguel que passou da data prevista
|   devolucao_proxima  devolução hoje ou nos próximos 2 dias
|   manutencao         carro na oficina (avisa se a previsão venceu)
|   cnh                cliente com CNH vencida ou vencendo em 30 dias
|   login_suspeito     3+ senhas erradas do mesmo e-mail em 24 h
|
| Cada pessoa vê só os alertas do que pode ver: a visão respeita as
| regras de acesso do banco (RLS). Ex.: login suspeito só o chefe vê.
*/

const DIAS_AVISO_DEVOLUCAO = 2;  // Devoluções nos próximos 2 dias (regra da visão)
const DIAS_AVISO_CNH       = 30; // CNH que vence em até 30 dias (regra da visão)

// Como cada tipo aparece na tela: título, cor da etiqueta, texto da
// etiqueta, para onde o botão leva e quem pode clicar nele.
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

/**
 * Os alertas agrupados por tipo: ['atraso' => [...], 'cnh' => [...], ...].
 * Uma pergunta só ao banco por página (o resultado fica guardado).
 */
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
        $lista = []; // sem alertas é melhor do que travar a página inteira
    }

    foreach ($lista as $alerta) {
        if (isset($grupos[$alerta['tipo']])) {
            $grupos[$alerta['tipo']][] = $alerta;
        }
    }

    return $grupos;
}

/** Total de alertas (aparece no menu lateral). */
function contar_alertas(): int
{
    return array_sum(array_map('count', buscar_alertas()));
}

/** Pode clicar no botão deste tipo de alerta? */
function pode_abrir_alerta(string $tipo): bool
{
    $permissao = TIPOS_ALERTA[$tipo]['permissao'];

    return $permissao === 'chefe' ? eh_chefe() : pode($permissao);
}

/** Endereço do botão de um alerta. */
function link_alerta(array $alerta): string
{
    $link = TIPOS_ALERTA[$alerta['tipo']]['link'];

    return str_ends_with($link, '=') ? $link . (int) $alerta['referencia_id'] : $link;
}
