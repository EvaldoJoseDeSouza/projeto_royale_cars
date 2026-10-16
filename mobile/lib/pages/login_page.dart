import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../theme/colors.dart';
import '../widgets/logo_widget.dart';
import 'main_dashboard_page.dart';
import 'trocar_senha_page.dart';

class LoginPage extends StatefulWidget {
  /// Recado para mostrar assim que a tela abrir (ex.: "Sua sessão terminou").
  final String? aviso;

  const LoginPage({super.key, this.aviso});

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
  void initState() {
    super.initState();
    final aviso = widget.aviso;
    if (aviso != null) {
      // Espera a tela terminar de desenhar para poder mostrar o recado
      WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarErro(aviso));
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: RoyaleColors.statusAlugado, content: Text(mensagem)),
    );
  }

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
      await authController.entrar(_loginController.text, _senhaController.text);
      if (!mounted) return;

      // Senha temporária (o chefe acabou de criar a conta ou redefinir):
      // antes de entrar no sistema, a pessoa cria a própria senha.
      if (authController.usuario!.trocarSenha) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TrocarSenhaPage(obrigatoria: true)),
        );
        return;
      }

      await carregarDados();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainDashboardPage()),
      );
    } catch (erro) {
      _mostrarErro(erro.toString().replaceFirst('Exception: ', ''));
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
              'Clientes, frota, locações e contratos — tudo em um só lugar,\nos mesmos dados da web e do desktop.',
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
                'Entre com o e-mail da sua conta',
                textAlign: TextAlign.center,
                style: TextStyle(color: RoyaleColors.textoMuted, fontSize: 13),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _loginController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe seu e-mail';
                  if (!v.contains('@')) return 'Entre com o seu e-mail de acesso';
                  return null;
                },
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
              // Não existe "criar conta" nem "esqueci a senha" pelo app:
              // quem cadastra a equipe e redefine senhas é o chefe.
              const Text(
                'Esqueceu a senha? Peça ao responsável pela locadora para redefinir.',
                textAlign: TextAlign.center,
                style: TextStyle(color: RoyaleColors.textoMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
