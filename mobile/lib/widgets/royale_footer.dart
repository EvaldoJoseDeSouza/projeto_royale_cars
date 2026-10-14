import 'package:flutter/material.dart';
import 'logo_widget.dart';

class RoyaleFooter extends StatelessWidget {
  const RoyaleFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: 80,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.black12, width: 0.5)),
          color: Colors.white,
        ),
        child: const Center(child: LogoWidget(width: 150)),
      ),
    );
  }
}
