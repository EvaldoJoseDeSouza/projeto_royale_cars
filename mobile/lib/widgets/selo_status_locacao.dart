import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Etiqueta colorida com o status do aluguel (as mesmas cores da web):
/// azul = Em andamento, vermelho = Atrasada, verde = Finalizada,
/// cinza = Cancelada.
class SeloStatusLocacao extends StatelessWidget {
  final String statusExibicao;

  const SeloStatusLocacao({super.key, required this.statusExibicao});

  @override
  Widget build(BuildContext context) {
    final cor = switch (statusExibicao) {
      'Atrasada' => RoyaleColors.statusAlugado,
      'Finalizada' => RoyaleColors.statusDisponivel,
      'Cancelada' => Colors.grey,
      _ => RoyaleColors.azulMarinho,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(20)),
      child: Text(statusExibicao, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
