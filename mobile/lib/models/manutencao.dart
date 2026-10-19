import '../utils/validadores.dart';

/// Manutenção (ida do carro para a oficina). Segue a tabela `manutencoes`
/// do banco unificado, a mesma da web e do desktop.
///
/// O antigo "laudo" do celular virou o CHECKLIST desta tabela: motor,
/// freios, pneus e óleo. Cada item pode ser:
///   true  = conferido e OK
///   false = conferido com problema
///   null  = não conferido (a vistoria é opcional)
class Manutencao {
  final int id;
  final int veiculoId;
  final int? locacaoId; // preenchido quando o carro voltou de um aluguel com defeito
  final String defeito;
  final String? oficina;
  final DateTime dataEntrada;
  final DateTime? previsaoLiberacao;
  final DateTime? dataLiberacao;
  final String? servicoRealizado;
  final double? custo;
  final String status; // 'Em andamento' | 'Concluída'
  final bool? motorOk;
  final bool? freiosOk;
  final bool? pneusOk;
  final bool? oleoOk;

  // Vêm "pendurados" no mesmo pedido (o carro e quem abriu/liberou)
  final String marca;
  final String modelo;
  final String placa;
  final String? abertaPor;
  final String? concluidaPor;

  static const statusEmAndamento = 'Em andamento';
  static const statusConcluida = 'Concluída';

  /// O checklist, na mesma ordem e com os mesmos nomes da web
  static const itensChecklist = ['Motor', 'Freios', 'Pneus', 'Óleo'];

  /// As colunas, com o carro e as pessoas "penduradas". A tabela aponta
  /// para perfis DUAS vezes (quem abriu e quem concluiu), por isso cada
  /// ligação leva o nome da regra (o mesmo jeito que a web faz).
  static const colunas = 'id, veiculo_id, locacao_id, defeito, oficina, data_entrada, previsao_liberacao, '
      'data_liberacao, servico_realizado, custo, status, motor_ok, freios_ok, pneus_ok, oleo_ok, '
      'veiculos(marca, modelo, placa), '
      'abriu:perfis!manutencoes_usuario_id_fkey(nome), '
      'concluiu:perfis!manutencoes_concluido_por_fkey(nome)';

  const Manutencao({
    required this.id,
    required this.veiculoId,
    this.locacaoId,
    required this.defeito,
    this.oficina,
    required this.dataEntrada,
    this.previsaoLiberacao,
    this.dataLiberacao,
    this.servicoRealizado,
    this.custo,
    required this.status,
    this.motorOk,
    this.freiosOk,
    this.pneusOk,
    this.oleoOk,
    required this.marca,
    required this.modelo,
    required this.placa,
    this.abertaPor,
    this.concluidaPor,
  });

  bool get emAndamento => status == statusEmAndamento;
  String get nomeVeiculo => '$marca $modelo';
  String get placaFormatada => mascaraPlaca(placa);

  /// Os 4 itens na ordem de [itensChecklist]
  List<bool?> get checklist => [motorOk, freiosOk, pneusOk, oleoOk];
  bool get temVistoria => checklist.any((item) => item != null);
  int get itensOk => checklist.where((item) => item == true).length;

  /// Há quantos dias o carro está (ou ficou) parado na oficina
  int get diasParado {
    final agora = DateTime.now();
    final fim = dataLiberacao ?? DateTime(agora.year, agora.month, agora.day);
    return fim.difference(dataEntrada).inDays;
  }

  /// A previsão de liberação já passou e o carro continua lá?
  bool get previsaoVencida {
    final agora = DateTime.now();
    return emAndamento && previsaoLiberacao != null && previsaoLiberacao!.isBefore(DateTime(agora.year, agora.month, agora.day));
  }

  static DateTime? _dataOuNula(dynamic v) => v == null ? null : DateTime.tryParse('$v');
  static int? _inteiro(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
  static Map<String, dynamic> _caixinha(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : {};

  factory Manutencao.fromMap(Map<String, dynamic> map) {
    final veiculo = _caixinha(map['veiculos']);

    return Manutencao(
      id: _inteiro(map['id']) ?? 0,
      veiculoId: _inteiro(map['veiculo_id']) ?? 0,
      locacaoId: _inteiro(map['locacao_id']),
      defeito: '${map['defeito'] ?? ''}',
      oficina: map['oficina'] as String?,
      dataEntrada: _dataOuNula(map['data_entrada']) ?? DateTime.now(),
      previsaoLiberacao: _dataOuNula(map['previsao_liberacao']),
      dataLiberacao: _dataOuNula(map['data_liberacao']),
      servicoRealizado: map['servico_realizado'] as String?,
      custo: map['custo'] == null ? null : (map['custo'] as num).toDouble(),
      status: '${map['status'] ?? statusEmAndamento}',
      motorOk: map['motor_ok'] as bool?,
      freiosOk: map['freios_ok'] as bool?,
      pneusOk: map['pneus_ok'] as bool?,
      oleoOk: map['oleo_ok'] as bool?,
      marca: '${veiculo['marca'] ?? ''}',
      modelo: '${veiculo['modelo'] ?? ''}',
      placa: '${veiculo['placa'] ?? ''}',
      abertaPor: _caixinha(map['abriu'])['nome'] as String?,
      concluidaPor: _caixinha(map['concluiu'])['nome'] as String?,
    );
  }
}
