import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../theme/colors.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_button.dart';
import '../widgets/royale_footer.dart';
import 'login_page.dart';
import 'trocar_senha_page.dart';

/// Minha conta (o mesmo nome da web e do desktop, decisão 12).
/// Cada pessoa muda o próprio NOME e a SENHA. E-mail, cargo e permissões
/// só o chefe muda, no Painel Administrativo (o banco garante isso).
class MinhaContaPage extends StatefulWidget {
  const MinhaContaPage({super.key});

  @override
  State<MinhaContaPage> createState() => _MinhaContaPageState();
}

class _MinhaContaPageState extends State<MinhaContaPage> {
  late final _nomeController = TextEditingController(text: authController.usuario?.nome);
  bool _salvando = false;

  // Os nomes "de gente" das 13 permissões (os mesmos da web e do desktop)
  static const _nomesPermissoes = {
    'clientes_ver': 'Ver clientes',
    'clientes_gerenciar': 'Cadastrar e editar clientes',
    'clientes_arquivar': 'Arquivar clientes',
    'veiculos_ver': 'Ver frota',
    'veiculos_gerenciar': 'Cadastrar e editar veículos',
    'veiculos_arquivar': 'Arquivar veículos',
    'locacoes_ver': 'Ver locações',
    'locacoes_gerenciar': 'Registrar retirada e devolução',
    'locacoes_cancelar': 'Cancelar locações',
    'manutencoes': 'Manutenção',
    'financeiro': 'Ver financeiro',
    'relatorios': 'Relatórios',
    'relatorios_financeiros': 'Valores nos relatórios',
  };

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _salvarNome() async {
    setState(() => _salvando = true);
    try {
      await authController.salvarNome(_nomeController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: RoyaleColors.statusDisponivel, content: Text('Seu nome foi atualizado.')),
      );
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: RoyaleColors.statusAlugado, content: Text(erro.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _sair() async {
    await authController.sair();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = authController.usuario;
    if (usuario == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const AnimatedGoldenTitle('Minha conta', fontSize: 24)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: RoyaleColors.dourado,
              child: Text(
                usuario.nome.isEmpty ? '?' : usuario.nome[0].toUpperCase(),
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: RoyaleColors.azulMarinho),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nomeController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome', prefixIcon: Icon(Icons.person)),
          ),
          const SizedBox(height: 12),
          _salvando
              ? const Center(child: CircularProgressIndicator(color: RoyaleColors.azulMarinho))
              : RoyaleButton(label: 'Salvar nome', onPressed: _salvarNome, fullWidth: true),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: Text(usuario.email),
                  subtitle: const Text('E-mail de acesso (só o chefe muda)'),
                ),
                ListTile(
                  leading: const Icon(Icons.work_outline),
                  title: Text(usuario.cargoTexto),
                  subtitle: const Text('Cargo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('O que você pode fazer', style: TextStyle(fontWeight: FontWeight.bold, color: RoyaleColors.azulMarinho)),
                  const SizedBox(height: 8),
                  if (usuario.ehChefe)
                    const Text('Como chefe, você tem acesso a tudo.')
                  else if (usuario.permissoes.isEmpty)
                    const Text('Nenhuma permissão liberada. Fale com o responsável pela locadora.')
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in _nomesPermissoes.entries)
                          if (usuario.permissoes.contains(p.key)) Chip(label: Text(p.value, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TrocarSenhaPage())),
            icon: const Icon(Icons.lock_outline),
            label: const Text('Trocar minha senha'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _sair,
            icon: const Icon(Icons.logout, color: RoyaleColors.statusAlugado),
            label: const Text('Sair da conta', style: TextStyle(color: RoyaleColors.statusAlugado)),
          ),
        ],
      ),
      bottomNavigationBar: const RoyaleFooter(),
    );
  }
}
