<?php
/*
|--------------------------------------------------------------------------
| ALERTAS AUTOMÁTICOS
|--------------------------------------------------------------------------
| Calculados na hora a partir do banco. Cada pessoa vê só os alertas dos
| módulos a que tem acesso.
*/

const DIAS_AVISO_DEVOLUCAO = 2;  // Avisar devoluções nos próximos 2 dias
const DIAS_AVISO_CNH       = 30; // Avisar CNH que vence em até 30 dias

function buscar_alertas(): array
{
    $alertas = [
        'atrasadas'           => [],
        'devolucoes_proximas' => [],
        'em_manutencao'       => [],
        'cnh'                 => [],
        'login_suspeito'      => [],
    ];

    if (pode('locacoes_ver')) {
        $alertas['atrasadas'] = db_todos(
            "SELECT l.id, l.data_prevista, l.valor_diaria,
                    DATEDIFF(CURDATE(), l.data_prevista) AS dias_atraso,
                    c.nome AS cliente, c.telefone,
                    v.marca, v.modelo, v.placa
             FROM locacoes l
             JOIN clientes c ON c.id = l.cliente_id
             JOIN veiculos v ON v.id = l.veiculo_id
             WHERE l.status = 'Em andamento' AND l.data_prevista < CURDATE()
             ORDER BY l.data_prevista"
        );

        $alertas['devolucoes_proximas'] = db_todos(
            "SELECT l.id, l.data_prevista,
                    DATEDIFF(l.data_prevista, CURDATE()) AS faltam,
                    c.nome AS cliente, c.telefone,
                    v.marca, v.modelo, v.placa
             FROM locacoes l
             JOIN clientes c ON c.id = l.cliente_id
             JOIN veiculos v ON v.id = l.veiculo_id
             WHERE l.status = 'Em andamento'
               AND l.data_prevista BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL ? DAY)
             ORDER BY l.data_prevista",
            [DIAS_AVISO_DEVOLUCAO]
        );
    }

    if (pode('manutencoes') || pode('veiculos_ver')) {
        $alertas['em_manutencao'] = db_todos(
            "SELECT m.id, m.defeito, m.oficina, m.data_entrada, m.previsao_liberacao,
                    DATEDIFF(CURDATE(), m.data_entrada) AS dias_parado,
                    (m.previsao_liberacao IS NOT NULL AND m.previsao_liberacao < CURDATE()) AS previsao_vencida,
                    v.id AS veiculo_id, v.marca, v.modelo, v.placa
             FROM manutencoes m
             JOIN veiculos v ON v.id = m.veiculo_id
             WHERE m.status = 'Em andamento'
             ORDER BY m.data_entrada"
        );
    }

    if (pode('clientes_ver')) {
        $alertas['cnh'] = db_todos(
            "SELECT id, nome, telefone, cnh_validade,
                    DATEDIFF(cnh_validade, CURDATE()) AS dias
             FROM clientes
             WHERE arquivado = 0
               AND cnh_validade <= DATE_ADD(CURDATE(), INTERVAL ? DAY)
             ORDER BY cnh_validade",
            [DIAS_AVISO_CNH]
        );
    }

    if (eh_chefe()) {
        $alertas['login_suspeito'] = db_todos(
            "SELECT email, ip, COUNT(*) AS falhas, MAX(criado_em) AS ultima
             FROM login_tentativas
             WHERE sucesso = 0 AND criado_em > DATE_SUB(NOW(), INTERVAL 24 HOUR)
             GROUP BY email, ip
             HAVING COUNT(*) >= 3
             ORDER BY falhas DESC"
        );
    }

    return $alertas;
}

/** Total de alertas (aparece no menu lateral). */
function contar_alertas(): int
{
    static $total = null;

    if ($total === null) {
        $total = 0;

        foreach (buscar_alertas() as $lista) {
            $total += count($lista);
        }
    }

    return $total;
}
