import 'package:flutter/material.dart';
import 'colors.dart';

/// Tema visual do app — usa a mesma paleta navy + dourado do desktop
/// (RoyaleColors), pra dar consistência profissional entre os produtos.
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: RoyaleColors.fundoApp,

      colorScheme: ColorScheme.fromSeed(
        seedColor: RoyaleColors.azulMarinho,
        primary: RoyaleColors.azulMarinho,
        secondary: RoyaleColors.dourado,
        surface: Colors.white,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: RoyaleColors.azulMarinho,
        centerTitle: true,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCED4DA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCED4DA)),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: Color(0xFF555555)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: RoyaleColors.azulMarinho, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: RoyaleColors.statusAlugado, width: 1.4),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RoyaleColors.azulMarinho,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: RoyaleColors.azulMarinho),
      ),
    );
  }

  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: RoyaleColors.azulMarinho,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );

  /// Botão de ação "positiva" (salvar/confirmar) — mesma cor verde
  /// usada no desktop para o .btn-save.
  static ButtonStyle get sucessoButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF28A745),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );

  /// Botão de ação "negativa" (cancelar/excluir/arquivar) — mesma cor
  /// vermelha usada no desktop para o .btn-cancel.
  static ButtonStyle get perigoButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFDC3545),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );
}
