/// Os dados do Painel e do Financeiro. Vêm prontos das VISÕES do banco
/// (consultas guardadas lá dentro), as MESMAS que a web e o desktop usam.
/// Por isso os números batem nas 3 plataformas:
///
///   vw_situacao_frota     → quantos carros disponíveis, alugados, na oficina
///   vw_alertas            → atrasos, devoluções próximas, CNH vencendo...
///   vw_faturamento_mensal → faturamento e gasto com manutenção, mês a mês
///
/// As visões respeitam as permissões de quem está logado: quem não pode
/// ver o financeiro recebe a lista vazia.
library;

double _numero(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
int _inteiro(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

/// Linha única de vw_situacao_frota.
class SituacaoFrota {
  final int disponiveis;
  final int alugados;
  final int emManutencao;
  final int total;

  const SituacaoFrota({this.disponiveis = 0, this.alugados = 0, this.emManutencao = 0, this.total = 0});

  factory SituacaoFrota.fromMap(Map<String, dynamic> m) => SituacaoFrota(
        disponiveis: _inteiro(m['disponiveis']),
        alugados: _inteiro(m['alugados']),
        emManutencao: _inteiro(m['em_manutencao']),
        total: _inteiro(m['total']),
      );
}

/// Um alerta de vw_alertas. O "tipo" diz o que é:
/// atraso | devolucao_proxima | manutencao | cnh | login_suspeito
class Alerta {
  final String tipo;
  final int? referenciaId; // id do aluguel, da manutenção ou do cliente
  final String titulo;
  final String detalhe;

  const Alerta({required this.tipo, this.referenciaId, required this.titulo, required this.detalhe});

  factory Alerta.fromMap(Map<String, dynamic> m) => Alerta(
        tipo: '${m['tipo']}',
        referenciaId: m['referencia_id'] == null ? null : _inteiro(m['referencia_id']),
        titulo: '${m['titulo'] ?? ''}',
        detalhe: '${m['detalhe'] ?? ''}',
      );

  /// Como cada tipo aparece na tela (os mesmos nomes da web)
  static const nomes = {
    'atraso': 'Aluguéis atrasados',
    'devolucao_proxima': 'Devoluções próximas',
    'manutencao': 'Veículos em manutenção',
    'cnh': 'CNH vencida ou vencendo',
    'login_suspeito': 'Tentativas suspeitas de login (24h)',
  };
}

/// Um mês de vw_faturamento_mensal.
class MesFinanceiro {
  final DateTime mes;
  final double faturamento;
  final int alugueis;
  final double manutencao;

  const MesFinanceiro({required this.mes, required this.faturamento, required this.alugueis, required this.manutencao});

  double get resultado => faturamento - manutencao;

  factory MesFinanceiro.fromMap(Map<String, dynamic> m) => MesFinanceiro(
        mes: DateTime.tryParse('${m['mes']}') ?? DateTime.now(),
        faturamento: _numero(m['faturamento']),
        alugueis: _inteiro(m['alugueis']),
        manutencao: _numero(m['manutencao']),
      );
}

/// Os números do Financeiro de um período (a mesma conta do desktop).
class ResumoFinanceiro {
  final double faturamento; // aluguéis finalizados no período
  final int alugueis;
  final double gastoManutencao; // manutenções concluídas no período
  final double aReceber; // aluguéis que ainda estão na rua
  final List<Map<String, dynamic>> entradas; // os aluguéis do período
  final List<MesFinanceiro> meses; // os últimos 12 meses

  const ResumoFinanceiro({
    required this.faturamento,
    required this.alugueis,
    required this.gastoManutencao,
    required this.aReceber,
    required this.entradas,
    required this.meses,
  });

  double get ticketMedio => alugueis > 0 ? faturamento / alugueis : 0;
  double get resultado => faturamento - gastoManutencao;
}
