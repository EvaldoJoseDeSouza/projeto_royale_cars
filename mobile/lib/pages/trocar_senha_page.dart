import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_button.dart';
import '../widgets/royale_footer.dart';
import 'login_page.dart';
import 'main_dashboard_page.dart';

/// Troca de senha, em dois jeitos (igual à web e ao desktop):
///
///  - [obrigatoria] = true: primeiro acesso com a senha temporária que o
///    chefe gerou. Não pede a senha atual (a pessoa acabou de entrar com
///    ela) e não deixa voltar: ou cria a senha, ou sai da conta.
///  - [obrigatoria] = false: troca normal, pelo menu. Pede a senha atual.
class TrocarSenhaPage extends StatefulWidget {
  final bool obrigatoria;

  const TrocarSenhaPage({super.key, this.obrigatoria = false});

  @override
  State<TrocarSenhaPage> createState() => _TrocarSenhaPageState();
}

class _TrocarSenhaPageState extends State<TrocarSenhaPage> {
  final _formKey = GlobalKey<FormState>();
  final _senhaAtualController = TextEditingController();
  final _novaSenhaController = TextEditingController();
  final _confirmarController = TextEditingController();
  bool _salvando = false;
  bool _senhasVisiveis = false;

  @override
  void dispose() {
    _senhaAtualController.dispose();
    _novaSenhaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);
    try {
      if (widget.obrigatoria) {
        await authController.criarSenhaPropria(_novaSenhaController.text);
        await carregarDados();
      } else {
        await authController.trocarSenha(
          senhaAtual: _senhaAtualController.text,
          novaSenha: _novaSenhaController.text,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: RoyaleColors.statusDisponivel,
          content: Text(widget.obrigatoria
              ? 'Pronto! Use essa senha nos próximos acessos.'
              : 'Sua senha foi alterada com sucesso!'),
        ),
      );

      if (widget.obrigatoria) {
        // Agora sim pode entrar no sistema (e não dá para "voltar" para cá)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainDashboardPage()),
          (route) => false,
        );
      } else {
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
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _sairDaConta() async {
    await authController.sair();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  /// Campo de senha com o "olhinho" para mostrar/esconder.
  Widget _campoSenha(TextEditingController controller, String rotulo, String? Function(String?) validar) {
    return TextFormField(
      controller: controller,
      obscureText: !_senhasVisiveis,
      decoration: InputDecoration(
        labelText: rotulo,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_senhasVisiveis ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _senhasVisiveis = !_senhasVisiveis),
        ),
      ),
      validator: validar,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nome = authController.usuario?.nome ?? '';

    return PopScope(
      // Na troca obrigatória, o botão "voltar" do Android não sai daqui
      canPop: !widget.obrigatoria,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.obrigatoria,
          title: AnimatedGoldenTitle(widget.obrigatoria ? 'Crie sua senha' : 'Trocar senha', fontSize: 22),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.obrigatoria) ...[
                  Text(
                    'Olá, $nome!',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: RoyaleColors.azulMarinho),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Você entrou com uma senha temporária. Para continuar, crie a sua própria senha.',
                    style: TextStyle(color: RoyaleColors.textoMuted),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  _campoSenha(_senhaAtualController, 'Senha atual',
                      (v) => (v == null || v.isEmpty) ? 'Informe a senha atual' : null),
                  const SizedBox(height: 16),
                ],
                _campoSenha(_novaSenhaController, 'Nova senha', (v) {
                  if (v == null || v.isEmpty) return 'Informe a nova senha';
                  if (!SupabaseService.senhaForte(v)) return SupabaseService.regraSenha;
                  return null;
                }),
                const SizedBox(height: 16),
                _campoSenha(_confirmarController, 'Repita a nova senha',
                    (v) => v != _novaSenhaController.text ? 'As senhas não são iguais' : null),
                const SizedBox(height: 8),
                const Text(
                  'Pelo menos 8 caracteres, com letras e números.',
                  style: TextStyle(color: RoyaleColors.textoMuted, fontSize: 12.5),
                ),
                const SizedBox(height: 32),
                _salvando
                    ? const Center(child: CircularProgressIndicator(color: RoyaleColors.azulMarinho))
                    : RoyaleButton(
                        label: widget.obrigatoria ? 'Criar senha' : 'Salvar nova senha',
                        onPressed: _salvar,
                        fullWidth: true,
                      ),
                if (widget.obrigatoria) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _salvando ? null : _sairDaConta,
                    child: const Text('Sair da conta'),
                  ),
                ],
              ],
            ),
          ),
        ),
        bottomNavigationBar: const RoyaleFooter(),
      ),
    );
  }
}
