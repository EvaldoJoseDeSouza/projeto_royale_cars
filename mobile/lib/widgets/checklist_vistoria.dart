import 'package:flutter/material.dart';
import '../models/manutencao.dart';
import '../theme/colors.dart';

/// Mostra o checklist da vistoria numa linha só:
///   ✔ Motor   ✔ Freios   ✖ Pneus   – Óleo
/// (✔ = OK, ✖ = com problema, – = não conferido)
class ChecklistVistoria extends StatelessWidget {
  final Manutencao manutencao;

  const ChecklistVistoria({super.key, required this.manutencao});

  @override
  Widget build(BuildContext context) {
    if (!manutencao.temVistoria) {
      return const Text('Sem vistoria', style: TextStyle(color: RoyaleColors.textoMuted, fontSize: 12.5));
    }

    final itens = manutencao.checklist;

    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        for (var i = 0; i < itens.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                itens[i] == null ? Icons.remove : (itens[i]! ? Icons.check_circle : Icons.cancel),
                size: 16,
                color: itens[i] == null
                    ? Colors.grey
                    : (itens[i]! ? RoyaleColors.statusDisponivel : RoyaleColors.statusAlugado),
              ),
              const SizedBox(width: 3),
              Text(Manutencao.itensChecklist[i], style: const TextStyle(fontSize: 12.5)),
            ],
          ),
      ],
    );
  }
}
