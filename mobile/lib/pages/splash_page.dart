import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../widgets/logo_widget.dart';
import 'login_page.dart';
import 'main_dashboard_page.dart';
import 'trocar_senha_page.dart';

/// Tela de abertura. Decide para onde o app vai:
///
///  - Sem sessão salva no aparelho → tela de login.
///  - Com sessão salva (a pessoa não clicou em "Sair" da última vez):
///    pergunta de novo ao banco o perfil e as permissões e entra direto.
///    Se o banco recusar (ex.: o chefe desativou a pessoa), volta para o
///    login com o recado.
///
/// Quem guarda a sessão no aparelho é o próprio supabase_flutter, sozinho.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _decidirDestino();
  }

  Future<void> _decidirDestino() async {
    // Um respiro para a marca aparecer
    await Future.delayed(const Duration(milliseconds: 600));

    Widget destino;

    if (!SupabaseService.instance.temSessaoSalva) {
      destino = const LoginPage();
    } else {
      try {
        await authController.retomarSessao();

        if (authController.usuario!.trocarSenha) {
          destino = const TrocarSenhaPage(obrigatoria: true);
        } else {
          await carregarDados();
          destino = const MainDashboardPage();
        }
      } catch (erro) {
        destino = LoginPage(aviso: erro.toString().replaceFirst('Exception: ', ''));
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => destino));
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
