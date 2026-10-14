<?php
/*
|--------------------------------------------------------------------------
| CARGOS E PERMISSÕES
|--------------------------------------------------------------------------
| O chefe tem acesso a tudo. Gerentes e funcionários só fazem o que o
| chefe marcar para cada um no Painel Administrativo.
*/

const CARGOS = [
    'chefe'       => 'Chefe',
    'gerente'     => 'Gerente',
    'funcionario' => 'Funcionário',
];

/** Permissões agrupadas por módulo (é assim que aparecem no formulário). */
const PERMISSOES = [
    'Clientes' => [
        'clientes_ver'       => 'Ver clientes',
        'clientes_gerenciar' => 'Cadastrar e editar clientes',
        'clientes_arquivar'  => 'Arquivar e reativar clientes',
    ],
    'Veículos' => [
        'veiculos_ver'       => 'Ver a frota',
        'veiculos_gerenciar' => 'Cadastrar e editar veículos (inclui preço da diária)',
        'veiculos_arquivar'  => 'Arquivar e reativar veículos',
    ],
    'Aluguéis' => [
        'locacoes_ver'       => 'Ver aluguéis',
        'locacoes_gerenciar' => 'Registrar retirada e devolução',
        'locacoes_cancelar'  => 'Cancelar aluguéis',
    ],
    'Manutenção' => [
        'manutencoes'        => 'Enviar veículos para manutenção e liberar',
    ],
    'Financeiro e relatórios' => [
        'financeiro'             => 'Ver o financeiro (faturamento e custos)',
        'relatorios'             => 'Ver relatórios de clientes, frota e aluguéis',
        'relatorios_financeiros' => 'Ver relatórios de faturamento',
    ],
];

/** Sugestão de permissões ao escolher o cargo (o chefe pode ajustar). */
const PERMISSOES_PADRAO = [
    'gerente' => [
        'clientes_ver', 'clientes_gerenciar', 'clientes_arquivar',
        'veiculos_ver', 'veiculos_gerenciar', 'veiculos_arquivar',
        'locacoes_ver', 'locacoes_gerenciar', 'locacoes_cancelar',
        'manutencoes', 'financeiro', 'relatorios', 'relatorios_financeiros',
    ],
    'funcionario' => [
        'clientes_ver', 'clientes_gerenciar',
        'veiculos_ver',
        'locacoes_ver', 'locacoes_gerenciar',
    ],
];

/**
 * Quem pode fazer algo também precisa poder ver.
 * Ex.: marcar "cadastrar clientes" adiciona "ver clientes" automaticamente.
 */
const PERMISSOES_DEPENDENTES = [
    'clientes_gerenciar'     => ['clientes_ver'],
    'clientes_arquivar'      => ['clientes_ver'],
    'veiculos_gerenciar'     => ['veiculos_ver'],
    'veiculos_arquivar'      => ['veiculos_ver'],
    'locacoes_gerenciar'     => ['locacoes_ver', 'clientes_ver', 'veiculos_ver'],
    'locacoes_cancelar'      => ['locacoes_ver'],
    'manutencoes'            => ['veiculos_ver'],
    'relatorios_financeiros' => ['relatorios'],
];

function todas_permissoes(): array
{
    $lista = [];

    foreach (PERMISSOES as $grupo) {
        $lista = array_merge($lista, array_keys($grupo));
    }

    return $lista;
}

function nome_permissao(string $chave): string
{
    foreach (PERMISSOES as $grupo) {
        if (isset($grupo[$chave])) {
            return $grupo[$chave];
        }
    }

    return $chave;
}

/** Remove permissões desconhecidas e acrescenta as dependências. */
function limpar_permissoes(array $marcadas): array
{
    $validas = array_values(array_intersect($marcadas, todas_permissoes()));

    foreach ($validas as $permissao) {
        foreach (PERMISSOES_DEPENDENTES[$permissao] ?? [] as $dependencia) {
            $validas[] = $dependencia;
        }
    }

    return array_values(array_unique($validas));
}
