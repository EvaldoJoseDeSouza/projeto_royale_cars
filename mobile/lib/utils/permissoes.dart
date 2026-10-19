/// As 13 permissões do sistema.
///
/// São as MESMAS chaves na web, no desktop e no celular (tabela
/// usuario_permissoes do banco). Ficam aqui num lugar só para ninguém
/// digitar 'clientes_ver' errado em alguma tela: escrevendo
/// Permissao.clientesVer, o próprio editor avisa se tiver erro.
///
/// O app usa isso só para ESCONDER o que a pessoa não pode usar.
/// Quem realmente proíbe é o banco (RLS): mesmo que alguém desse um
/// "jeitinho" no app, o banco recusaria.
class Permissao {
  Permissao._(); // ninguém cria um "Permissao()": é só uma caixa de constantes

  // Clientes
  static const clientesVer = 'clientes_ver';
  static const clientesGerenciar = 'clientes_gerenciar';
  static const clientesArquivar = 'clientes_arquivar';

  // Frota
  static const veiculosVer = 'veiculos_ver';
  static const veiculosGerenciar = 'veiculos_gerenciar';
  static const veiculosArquivar = 'veiculos_arquivar';

  // Locações
  static const locacoesVer = 'locacoes_ver';
  static const locacoesGerenciar = 'locacoes_gerenciar';
  static const locacoesCancelar = 'locacoes_cancelar';

  // Manutenção
  static const manutencoes = 'manutencoes';

  // Financeiro e relatórios (no celular, só para ler)
  static const financeiro = 'financeiro';
  static const relatorios = 'relatorios';
  static const relatoriosFinanceiros = 'relatorios_financeiros';
}
