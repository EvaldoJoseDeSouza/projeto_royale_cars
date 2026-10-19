import '../utils/validadores.dart';

/// Veículo da frota. Segue a tabela `veiculos` do banco unificado (a
/// mesma da web e do desktop).
///
/// O STATUS não se escolhe no formulário: ele muda sozinho, pelas
/// funções do banco (igual na web e no desktop):
///   Disponível    → Alugado        quando um aluguel é registrado
///   Alugado       → Disponível     quando o carro é devolvido
///   Disponível    → Em manutenção  quando vai para a oficina
///   Em manutenção → Disponível     quando a manutenção é concluída
///
/// Placa e chassi ficam no banco em maiúsculas, sem hífen nem espaços
/// ("ABC1234", "ABC1D23"). O hífen aparece só na tela (placaFormatada).
class Veiculo {
  final int? id; // null = veículo novo, ainda não salvo
  final String marca;
  final String modelo;
  final int ano;
  final String placa;
  final String chassi;
  final double valorDiaria;
  final int quilometragem;
  final String? imagem; // caminho da foto no Storage (bucket "veiculos")
  final String status;
  final bool arquivado;

  // Os 3 status, escritos EXATAMENTE como no banco (tipo status_veiculo)
  static const statusDisponivel = 'Disponível';
  static const statusAlugado = 'Alugado';
  static const statusManutencao = 'Em manutenção';

  /// As colunas que as telas usam (nunca "select *": só o que precisa)
  static const colunas = 'id, marca, modelo, ano, placa, chassi, valor_diaria, quilometragem, imagem, status, arquivado';

  const Veiculo({
    this.id,
    required this.marca,
    required this.modelo,
    required this.ano,
    required this.placa,
    required this.chassi,
    required this.valorDiaria,
    this.quilometragem = 0,
    this.imagem,
    this.status = statusDisponivel,
    this.arquivado = false,
  });

  bool get isDisponivel => status == statusDisponivel;
  String get nomeCompleto => '$marca $modelo';
  String get placaFormatada => mascaraPlaca(placa);

  static double _paraDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;
  static int _paraInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  /// Lê uma linha que veio do banco.
  factory Veiculo.fromMap(Map<String, dynamic> map) {
    return Veiculo(
      id: map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}'),
      marca: '${map['marca'] ?? ''}',
      modelo: '${map['modelo'] ?? ''}',
      ano: _paraInt(map['ano']),
      placa: '${map['placa'] ?? ''}',
      chassi: '${map['chassi'] ?? ''}',
      valorDiaria: _paraDouble(map['valor_diaria']),
      quilometragem: _paraInt(map['quilometragem']),
      imagem: map['imagem'] as String?,
      status: '${map['status'] ?? statusDisponivel}',
      arquivado: map['arquivado'] == true,
    );
  }

  /// O que vai para o banco ao cadastrar ou editar.
  /// Repare: "status" e "imagem" NÃO vão juntos. Veículo novo entra
  /// Disponível (o banco garante) e depois só aluguéis e manutenções
  /// mudam o status. A foto continua a mesma.
  Map<String, dynamic> toMap() {
    return {
      'marca': marca.trim().replaceAll(RegExp(r'\s+'), ' '),
      'modelo': modelo.trim().replaceAll(RegExp(r'\s+'), ' '),
      'ano': ano,
      'placa': limparCodigo(placa),
      'chassi': limparCodigo(chassi),
      'valor_diaria': valorDiaria,
      'quilometragem': quilometragem,
    };
  }
}
