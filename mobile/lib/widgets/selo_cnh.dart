import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../theme/colors.dart';

/// Etiqueta colorida com a situação da CNH do cliente (a mesma ideia do
/// alerta "CNH vencida ou vencendo" da web e do desktop):
///   vermelha → já venceu (o banco não deixa alugar)
///   laranja  → vence em até 30 dias
///   nada     → está em dia
class SeloCnh extends StatelessWidget {
  final Cliente cliente;

  const SeloCnh({super.key, required this.cliente});

  @override
  Widget build(BuildContext context) {
    final dias = cliente.diasParaVencerCnh;

    if (dias > 30) return const SizedBox.shrink(); // em dia: não mostra nada

    final vencida = dias < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: vencida ? RoyaleColors.statusAlugado : RoyaleColors.statusManutencao,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        vencida ? 'CNH vencida' : (dias == 0 ? 'CNH vence hoje' : 'CNH vence em $dias dia(s)'),
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
