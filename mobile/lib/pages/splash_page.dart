import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../widgets/logo_widget.dart';
import 'login_page.dart';

/// Tela de abertura rápida (marca + conexão com o Supabase já
/// inicializada em main.dart). Diferente da versão anterior (SQLite),
/// aqui não há dados pra pré-carregar antes do login: os dados de
/// clientes/veículos/locações só fazem sentido DEPOIS de saber qual
/// empresa (id_empresa) está logada.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _irParaLogin();
  }

  Future<void> _irParaLogin() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RoyaleColors.azulMarinho,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LogoWidget(width: 220),
            const SizedBox(height: 32),
            CircularProgressIndicator(color: RoyaleColors.dourado),
          ],
        ),
      ),
    );
  }
}
