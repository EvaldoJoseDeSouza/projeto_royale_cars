import 'package:flutter/material.dart';

class AnimatedGoldenTitle extends StatefulWidget {
  final String text;
  final double fontSize;

  const AnimatedGoldenTitle(this.text, {this.fontSize = 24, super.key});

  @override
  State<AnimatedGoldenTitle> createState() => _AnimatedGoldenTitleState();
}

class _AnimatedGoldenTitleState extends State<AnimatedGoldenTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(8),
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: const [Colors.amber, Colors.orangeAccent, Colors.yellow],
              begin: Alignment(-1 + _controller.value * 2, 0),
              end: Alignment(1 - _controller.value * 2, 0),
            ).createShader(bounds),
            child: Text(
              widget.text,
              style: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}
