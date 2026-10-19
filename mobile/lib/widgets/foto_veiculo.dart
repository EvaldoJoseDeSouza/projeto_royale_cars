import 'package:flutter/material.dart';
import '../models/veiculo.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';

/// Foto do veículo, a mesma que a web e o desktop mostram (fica no
/// Supabase Storage). Sem foto, ou sem internet, aparece um ícone de carro.
class FotoVeiculo extends StatelessWidget {
  final Veiculo veiculo;
  final double tamanho;

  const FotoVeiculo({super.key, required this.veiculo, this.tamanho = 56});

  @override
  Widget build(BuildContext context) {
    final url = SupabaseService.instance.urlFoto(veiculo.imagem);

    final iconePadrao = Container(
      width: tamanho,
      height: tamanho,
      color: RoyaleColors.fundoApp,
      child: Icon(Icons.directions_car, color: RoyaleColors.azulMarinho, size: tamanho * 0.55),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: url == null
          ? iconePadrao
          : Image.network(
              url,
              width: tamanho,
              height: tamanho,
              fit: BoxFit.cover,
              // Se a foto não carregar (sem internet, arquivo apagado), mostra o ícone
              errorBuilder: (context, erro, pilha) => iconePadrao,
            ),
    );
  }
}
