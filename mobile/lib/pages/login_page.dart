import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../theme/colors.dart';
import '../widgets/logo_widget.dart';
import 'cadastro_empresa_page.dart';
import 'main_dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginController = TextEditingController();
  final _senhaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _carregando = false;
  bool _senhaVisivel = false;

  @override
  void dispose() {
    _loginController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _efetuarLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);

    try {
      await authController.login(_loginController.text.trim(), _senhaController.text);

      final idEmpresa = authController.idEmpresa;
      if (idEmpresa != null) {
        await carregarDadosDaEmpresa(idEmpresa);
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainDashboardPage()),
        );
      }
    } catch (erro) {
      final mensagem = erro.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: RoyaleColors.statusAlugado, content: Text(mensagem)),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final larguraTela = MediaQuery.of(context).size.width;
    final ehTelaLarga = larguraTela > 900;

    return Scaffold(
      body: ehTelaLarga ? _layoutDividido() : _layoutEmpilhado(),
    );
  }

  // Telas largas (desktop/tablet): banner navy à esquerda + formulário
  // à direita, igual ao login do app desktop.
  Widget _layoutDividido() {
    return Row(
      children: [
        Expanded(flex: 5, child: _bannerLateral()),
        Expanded(flex: 4, child: Center(child: _cartaoFormulario())),
      ],
    );
  }

  // Celular (retrato): banner navy no topo + formulário embaixo.
  Widget _layoutEmpilhado() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 280, child: _bannerLateral(compacto: true)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: _cartaoFormulario(),
          ),
        ],
      ),
    );
  }

  Widget _bannerLateral({bool compacto = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: compacto ? 28 : 60, vertical: compacto ? 20 : 60),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [RoyaleColors.azulMarinho, Color(0xFF041455)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      // 🌟 SingleChildScrollView evita que o texto "empurre" o Column pra
      // fora da altura disponível (o erro de overflow que apareceu no
      // Chrome) — se sobrar pouco espaço, ele rola em vez de vazar.
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LogoWidget(width: compacto ? 110 : 180),
            SizedBox(height: compacto ? 16 : 24),
            Text(
              'Gestão completa\npara sua locadora',
              style: TextStyle(
                color: Colors.white,
                fontSize: compacto ? 20 : 32,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Clientes, frota, locações e contratos — tudo em um só lugar,\nsincronizado em tempo real com o painel desktop.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: compacto ? 12.5 : 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartaoFormulario() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Bem-vindo de volta',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: RoyaleColors.azulMarinho),
              ),
              const SizedBox(height: 6),
              const Text(
                'Entre com o e-mail ou usuário da sua conta',
                textAlign: TextAlign.center,
                style: TextStyle(color: RoyaleColors.textoMuted, fontSize: 13),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _loginController,
                decoration: const InputDecoration(
                  labelText: 'E-mail ou usuário',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe seu e-mail ou usuário' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _senhaController,
                obscureText: !_senhaVisivel,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_senhaVisivel ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Informe sua senha' : null,
                onFieldSubmitted: (_) => _efetuarLogin(),
              ),
              const SizedBox(height: 28),
              _carregando
                  ? const Center(child: CircularProgressIndicator(color: RoyaleColors.azulMarinho))
                  : ElevatedButton(onPressed: _efetuarLogin, child: const Text('ENTRAR')),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CadastroEmpresaPage()),
                  );
                },
                child: const Text('Ainda não tem conta? Criar conta da locadora'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
