import 'package:flutter/material.dart';

class RoyaleButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final bool fullWidth; // Nova propriedade!

  const RoyaleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.backgroundColor = const Color.fromARGB(255, 34, 48, 78),
    this.fullWidth = false, // Por padrão, ele não ocupa a tela toda
  });

  @override
  Widget build(BuildContext context) {
    // Usamos o LayoutBuilder ou simplesmente alinhamos o botão
    return Center(
      // O segredo está aqui: ele força a centralização independente da página
      child: SizedBox(
        width: fullWidth
            ? double.infinity
            : null, // Se for fullWidth, ignora o tamanho fixo
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            // Se fullWidth for true, a largura é infinita, senão é 200
            minimumSize: Size(fullWidth ? double.infinity : 200, 50),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 4,
          ),
          onPressed: onPressed,
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
