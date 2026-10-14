import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../theme/colors.dart';
import '../utils/validadores.dart';
import '../widgets/logo_widget.dart';

/// Cadastro de uma nova conta/empresa — mesmo fluxo "Proprietário" do
/// app desktop: a conta criada AQUI já enxerga (e compartilha) os
/// mesmos dados no Supabase, caso o usuário use o mesmo e-mail/login
/// já cadastrado por lá.
class CadastroEmpresaPage extends StatefulWidget {
  const CadastroEmpresaPage({super.key});

  @override
  State<CadastroEmpresaPage> createState() => _CadastroEmpresaPageState();
}

class _CadastroEmpresaPageState extends State<CadastroEmpresaPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  bool _carregando = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _criarConta() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);

    try {
      await authController.criarConta(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        senha: _senhaController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: RoyaleColors.statusDisponivel,
            content: Text('Conta criada com sucesso! Faça login para continuar.'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: RoyaleColors.statusAlugado,
            content: Text(erro.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta da locadora')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LogoWidget(width: 140),
                  const SizedBox(height: 24),
                  const Text(
                    'Essa conta vai representar sua locadora — todos os clientes, '
                    'veículos e locações ficam vinculados a ela.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: RoyaleColors.textoMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Nome de usuário', prefixIcon: Icon(Icons.badge_outlined)),
                    validator: (v) => obrigatorio(v, 'O nome de usuário'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email_outlined)),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                      return emailValido(v) ? null : 'E-mail inválido';
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _senhaController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Senha', prefixIcon: Icon(Icons.lock_outline)),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Informe a senha';
                      if (v.length < 6) return 'A senha precisa ter ao menos 6 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmarSenhaController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirmar senha', prefixIcon: Icon(Icons.lock_outline)),
                    validator: (v) {
                      if (v != _senhaController.text) return 'As senhas não coincidem';
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  _carregando
                      ? const Center(child: CircularProgressIndicator(color: RoyaleColors.azulMarinho))
                      : ElevatedButton(onPressed: _criarConta, child: const Text('CRIAR CONTA')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
