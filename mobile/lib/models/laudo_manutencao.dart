/// Laudo de manutenção (checklist do veículo). Tabela nova
/// `laudos_manutencao`, exclusiva do app Flutter (não existe no
/// desktop, que só marca o veículo com status "Em Manutenção").
class LaudoManutencao {
  final int? id;
  final int? idEmpresa;
  final int idVeiculo;
  final String placa;
  final bool motorOk;
  final bool freiosOk;
  final bool pneusOk;
  final bool oleoOk;
  final String observacoes;
  final DateTime dataRegistro;

  LaudoManutencao({
    this.id,
    this.idEmpresa,
    required this.idVeiculo,
    required this.placa,
    required this.motorOk,
    required this.freiosOk,
    required this.pneusOk,
    required this.oleoOk,
    required this.observacoes,
    required this.dataRegistro,
  });

  static bool _paraBool(dynamic v, [bool padrao = true]) {
    if (v is bool) return v;
    if (v == null) return padrao;
    return v.toString() == 'true' || v.toString() == '1';
  }

  factory LaudoManutencao.fromMap(Map<String, dynamic> map) {
    return LaudoManutencao(
      id: map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}'),
      idEmpresa: map['id_empresa'] is int
          ? map['id_empresa'] as int
          : int.tryParse('${map['id_empresa']}'),
      idVeiculo: map['id_veiculo'] is int
          ? map['id_veiculo'] as int
          : int.tryParse('${map['id_veiculo']}') ?? 0,
      placa: map['placa'] ?? '',
      motorOk: _paraBool(map['motor_ok']),
      freiosOk: _paraBool(map['freios_ok']),
      pneusOk: _paraBool(map['pneus_ok']),
      oleoOk: _paraBool(map['oleo_ok']),
      observacoes: map['observacoes'] ?? '',
      dataRegistro: DateTime.tryParse('${map['data_registro']}') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_veiculo': idVeiculo,
      'placa': placa,
      'motor_ok': motorOk,
      'freios_ok': freiosOk,
      'pneus_ok': pneusOk,
      'oleo_ok': oleoOk,
      'observacoes': observacoes,
      'data_registro': dataRegistro.toIso8601String(),
    };
  }
}
