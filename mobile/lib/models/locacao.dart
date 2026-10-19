import '../utils/validadores.dart';

/// Locação (aluguel). Os dados vêm da visão `vw_locacoes` do banco, a
/// MESMA que a web e o desktop usam: a linha do aluguel + nome do
/// cliente + dados do carro + o status "Atrasada" já calculado.
///
/// O app NÃO calcula nem grava o aluguel direto na tabela: quem faz isso
/// são as funções do banco (registrar_aluguel, registrar_devolucao,
/// cancelar_aluguel). Assim a conta é igual nas 3 plataformas.
class Locacao {
  final int id;
  final int clienteId;
  final int veiculoId;
  final DateTime dataRetirada;
  final DateTime dataPrevista;
  final DateTime? dataDevolucao; // só depois da devolução
  final double valorDiaria; // a diária da época (se o preço mudar depois, o aluguel não muda)
  final int diasPrevistos;
  final double valorPrevisto;
  final int diasAtraso;
  final double valorAtraso;
  final double taxasExtras;
  final String? taxasMotivo;
  final double valorTotal;
  final String status; // 'Em andamento' | 'Finalizada' | 'Cancelada'
  final String statusExibicao; // igual ao status, mas diz 'Atrasada' quando passou da data
  final String? observacoes;
  final int? kmSaida;
  final int? kmRetorno;
  final String? assinaturaPath; // caminho do PNG no bucket "contratos"

  // Vêm "pendurados" pela visão (não são colunas da tabela locacoes)
  final String nomeCliente;
  final String marca;
  final String modelo;
  final String placa;

  // Os status, escritos EXATAMENTE como no banco (tipo status_locacao)
  static const statusEmAndamento = 'Em andamento';
  static const statusFinalizada = 'Finalizada';
  static const statusCancelada = 'Cancelada';

  /// As colunas que as telas usam (da visão vw_locacoes)
  static const colunas = 'id, cliente_id, veiculo_id, data_retirada, data_prevista, data_devolucao, '
      'valor_diaria, dias_previstos, valor_previsto, dias_atraso, valor_atraso, taxas_extras, taxas_motivo, '
      'valor_total, status, status_exibicao, observacoes, km_saida, km_retorno, assinatura_path, '
      'cliente_nome, marca, modelo, placa';

  const Locacao({
    required this.id,
    required this.clienteId,
    required this.veiculoId,
    required this.dataRetirada,
    required this.dataPrevista,
    this.dataDevolucao,
    required this.valorDiaria,
    required this.diasPrevistos,
    required this.valorPrevisto,
    this.diasAtraso = 0,
    this.valorAtraso = 0,
    this.taxasExtras = 0,
    this.taxasMotivo,
    required this.valorTotal,
    required this.status,
    required this.statusExibicao,
    this.observacoes,
    this.kmSaida,
    this.kmRetorno,
    this.assinaturaPath,
    required this.nomeCliente,
    required this.marca,
    required this.modelo,
    required this.placa,
  });

  bool get emAndamento => status == statusEmAndamento;
  bool get atrasada => statusExibicao == 'Atrasada';
  bool get temAssinatura => assinaturaPath != null && assinaturaPath!.isNotEmpty;
  String get nomeVeiculo => '$marca $modelo';
  String get placaFormatada => mascaraPlaca(placa);
  int? get kmRodados => (kmSaida != null && kmRetorno != null) ? kmRetorno! - kmSaida! : null;

  static double _paraDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  static int? _paraIntOuNulo(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
  static DateTime _data(dynamic v) => DateTime.tryParse('$v') ?? DateTime.now();

  /// Lê uma linha da visão vw_locacoes.
  factory Locacao.fromMap(Map<String, dynamic> map) {
    return Locacao(
      id: _paraIntOuNulo(map['id']) ?? 0,
      clienteId: _paraIntOuNulo(map['cliente_id']) ?? 0,
      veiculoId: _paraIntOuNulo(map['veiculo_id']) ?? 0,
      dataRetirada: _data(map['data_retirada']),
      dataPrevista: _data(map['data_prevista']),
      dataDevolucao: map['data_devolucao'] == null ? null : _data(map['data_devolucao']),
      valorDiaria: _paraDouble(map['valor_diaria']),
      diasPrevistos: _paraIntOuNulo(map['dias_previstos']) ?? 1,
      valorPrevisto: _paraDouble(map['valor_previsto']),
      diasAtraso: _paraIntOuNulo(map['dias_atraso']) ?? 0,
      valorAtraso: _paraDouble(map['valor_atraso']),
      taxasExtras: _paraDouble(map['taxas_extras']),
      taxasMotivo: map['taxas_motivo'] as String?,
      valorTotal: _paraDouble(map['valor_total']),
      status: '${map['status'] ?? statusEmAndamento}',
      statusExibicao: '${map['status_exibicao'] ?? map['status'] ?? statusEmAndamento}',
      observacoes: map['observacoes'] as String?,
      kmSaida: _paraIntOuNulo(map['km_saida']),
      kmRetorno: _paraIntOuNulo(map['km_retorno']),
      assinaturaPath: map['assinatura_path'] as String?,
      nomeCliente: '${map['cliente_nome'] ?? ''}',
      marca: '${map['marca'] ?? ''}',
      modelo: '${map['modelo'] ?? ''}',
      placa: '${map['placa'] ?? ''}',
    );
  }
}
