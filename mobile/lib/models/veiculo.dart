/// Veículo da frota. Segue a tabela `veiculos` do Supabase (mesma do
/// desktop): modelo, marca, placa, diária e status — que aqui é uma
/// String ('Disponível' | 'Alugado' | 'Em Manutenção'), igual ao
/// desktop, em vez do antigo bool isDisponivel.
///
/// 🌟 quilometragem é um campo novo (não existe no desktop ainda),
/// adicionado para atender ao pedido da banca de acompanhamento de km.
class Veiculo {
  final int? id;
  final int? idEmpresa;
  final String modelo;
  final String marca;
  final String placa;
  final double diaria;
  final String status;
  final bool ativo;
  final int quilometragem;

  static const statusDisponivel = 'Disponível';
  static const statusAlugado = 'Alugado';
  static const statusManutencao = 'Em Manutenção';

  Veiculo({
    this.id,
    this.idEmpresa,
    required this.modelo,
    required this.marca,
    required this.placa,
    required this.diaria,
    this.status = statusDisponivel,
    this.ativo = true,
    this.quilometragem = 0,
  });

  bool get isDisponivel => status == statusDisponivel;

  Veiculo copyWith({
    int? id,
    int? idEmpresa,
    String? modelo,
    String? marca,
    String? placa,
    double? diaria,
    String? status,
    bool? ativo,
    int? quilometragem,
  }) {
    return Veiculo(
      id: id ?? this.id,
      idEmpresa: idEmpresa ?? this.idEmpresa,
      modelo: modelo ?? this.modelo,
      marca: marca ?? this.marca,
      placa: placa ?? this.placa,
      diaria: diaria ?? this.diaria,
      status: status ?? this.status,
      ativo: ativo ?? this.ativo,
      quilometragem: quilometragem ?? this.quilometragem,
    );
  }

  static double _paraDouble(dynamic v, [double padrao = 0]) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? padrao;
  }

  static int _paraInt(dynamic v, [int padrao = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? padrao;
  }

  factory Veiculo.fromMap(Map<String, dynamic> map) {
    return Veiculo(
      id: map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}'),
      idEmpresa: map['id_empresa'] is int
          ? map['id_empresa'] as int
          : int.tryParse('${map['id_empresa']}'),
      modelo: map['modelo'] ?? '',
      marca: map['marca'] ?? '',
      placa: map['placa'] ?? '',
      diaria: _paraDouble(map['diaria']),
      status: map['status'] ?? statusDisponivel,
      ativo: map['ativo'] is bool ? map['ativo'] as bool : (map['ativo'] == null ? true : map['ativo'].toString() == 'true'),
      quilometragem: _paraInt(map['quilometragem']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'modelo': modelo,
      'marca': marca,
      'placa': placa,
      'diaria': diaria,
      'status': status,
      'quilometragem': quilometragem,
    };
  }
}
