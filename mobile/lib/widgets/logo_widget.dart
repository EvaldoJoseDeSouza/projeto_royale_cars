import 'package:flutter/material.dart';

class LogoWidget extends StatelessWidget {
  final double width;

  const LogoWidget({this.width = 300, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/images/logoroyale.png', // caminho da sua imagem
        width: width,
      ),
    );
  }
}
