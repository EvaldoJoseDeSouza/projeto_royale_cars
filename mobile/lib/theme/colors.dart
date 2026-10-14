import 'package:flutter/material.dart';

/// Paleta oficial do Royale Cars — a MESMA usada no app desktop
/// (royale-cars-desktop/src/renderer/dashboard.css), pra manter os
/// três produtos (app, desktop, web) visualmente consistentes.
class RoyaleColors {
  static const azulMarinho = Color(0xFF010D3D); // --bg-sidebar / --blue-dark
  static const dourado = Color(0xFFFFC107); // --gold
  static const fundoApp = Color(0xFFF4F7F6); // --bg-app
  static const textoPrincipal = Color(0xFF333333); // --text-main
  static const textoMuted = Color(0xFF777777); // --text-muted
  static const bordaClara = Color(0xFFE0E4E2); // --border-color

  // Status de veículo/locação (mesmos conceitos do desktop)
  static const statusDisponivel = Color(0xFF2E7D32);
  static const statusAlugado = Color(0xFFD9534F);
  static const statusManutencao = Color(0xFFE0A800);
}

/// Mantido por compatibilidade com o restante do app — agora aponta
/// pra mesma paleta oficial em vez das cores antigas (cinza-esverdeado).
class AppColors {
  static const primaryGreen = RoyaleColors.azulMarinho;
  static const primaryDarkGreen = RoyaleColors.azulMarinho;
  static const accentOlive = RoyaleColors.dourado;
  static const background = RoyaleColors.fundoApp;
  static const surface = Colors.white;
  static const statusAvailable = RoyaleColors.statusDisponivel;
  static const statusRented = RoyaleColors.statusAlugado;
}
