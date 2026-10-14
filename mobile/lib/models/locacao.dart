/// Locação. Segue a tabela `locacoes` do Supabase (mesma do desktop):
/// id_cliente, id_veiculo, data_inicio, data_fim, valor_total, status
/// ('Ativo' | 'Concluído').
///
/// 🌟 Campos novos (não existem no desktop ainda), adicionados para
/// atender ao pedido da banca:
/// - kmSaida / kmRetorno: quilometragem registrada na retirada/devolução
/// - assinaturaBase64: assinatura digital do cliente (contrato)
class Locacao {
  final int? id;
  final int? idEmpresa;
  final int idCliente;
  final int idVeiculo;
  final DateTime dataInicio;
  final DateTime dataFim;
  final double valorTotal;
  final String status;
  final int? kmSaida;
  final int? kmRetorno;
  final String? assinaturaBase64;

  // Preenchidos apenas quando a consulta faz join com clientes/veiculos
  // (não são colunas próprias da tabela locacoes)
  final String? nomeCliente;
  final String? modeloVeiculo;
  final String? placaVeiculo;

  static const statusAtivo = 'Ativo';
  static const statusConcluido = 'Concluído';

  Locacao({
    this.id,
    this.idEmpresa,
    required this.idCliente,
    required this.idVeiculo,
    required this.dataInicio,
    required this.dataFim,
    required this.valorTotal,
    this.status = statusAtivo,
    this.kmSaida,
    this.kmRetorno,
    this.assinaturaBase64,
    this.nomeCliente,
    this.modeloVeiculo,
    this.placaVeiculo,
  });

  int? get kmRodados =>
      (kmSaida != null && kmRetorno != null) ? (kmRetorno! - kmSaida!) : null;

  static double _paraDouble(dynamic v, [double padrao = 0]) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? padrao;
  }

  static int? _paraIntOuNulo(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  factory Locacao.fromMap(Map<String, dynamic> map) {
    return Locacao(
      id: map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}'),
      idEmpresa: _paraIntOuNulo(map['id_empresa']),
      idCliente: _paraIntOuNulo(map['id_cliente']) ?? 0,
      idVeiculo: _paraIntOuNulo(map['id_veiculo']) ?? 0,
      dataInicio: DateTime.tryParse('${map['data_inicio']}') ?? DateTime.now(),
      dataFim: DateTime.tryParse('${map['data_fim']}') ?? DateTime.now(),
      valorTotal: _paraDouble(map['valor_total']),
      status: map['status'] ?? statusAtivo,
      kmSaida: _paraIntOuNulo(map['km_saida']),
      kmRetorno: _paraIntOuNulo(map['km_retorno']),
      assinaturaBase64: map['assinatura_base64'],
      // Vem como objeto aninhado quando a query usa
      // .select('..., clientes(nome), veiculos(modelo, placa)')
      nomeCliente: map['clientes'] is Map ? map['clientes']['nome'] : null,
      modeloVeiculo: map['veiculos'] is Map ? map['veiculos']['modelo'] : null,
      placaVeiculo: map['veiculos'] is Map ? map['veiculos']['placa'] : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_cliente': idCliente,
      'id_veiculo': idVeiculo,
      'data_inicio': dataInicio.toIso8601String().split('T').first,
      'data_fim': dataFim.toIso8601String().split('T').first,
      'valor_total': valorTotal,
      'status': status,
      if (kmSaida != null) 'km_saida': kmSaida,
      if (kmRetorno != null) 'km_retorno': kmRetorno,
      if (assinaturaBase64 != null) 'assinatura_base64': assinaturaBase64,
    };
  }
}
