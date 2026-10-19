import 'package:flutter/material.dart';
import '../models/veiculo.dart';
import '../theme/colors.dart';

/// Etiqueta colorida com o status do veículo (as mesmas cores do desktop):
/// verde = Disponível, vermelho = Alugado, amarelo = Em manutenção.
class SeloStatusVeiculo extends StatelessWidget {
  final String status;

  const SeloStatusVeiculo({super.key, required this.status});

  static Color corDoStatus(String status) => switch (status) {
        Veiculo.statusDisponivel => RoyaleColors.statusDisponivel,
        Veiculo.statusManutencao => RoyaleColors.statusManutencao,
        _ => RoyaleColors.statusAlugado,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: corDoStatus(status), borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
