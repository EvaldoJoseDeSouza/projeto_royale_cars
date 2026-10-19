import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../theme/colors.dart';
import '../utils/permissoes.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_footer.dart';
import 'cadastro_veiculo_page.dart';
import 'clientes_page.dart';
import 'devolucao_page.dart';
import 'financas_page.dart';
import 'frota_page.dart';
import 'locacao_page.dart';
import 'login_page.dart';
import 'manutencao_page.dart';
import 'menu_relatorios_page.dart';
import 'sobre_nos_page.dart';
import 'trocar_senha_page.dart';

class MainDashboardPage extends StatefulWidget {
  const MainDashboardPage({super.key});

  @override
  State<MainDashboardPage> createState() => _MainDashboardPageState();
}

class _MainDashboardPageState extends State<MainDashboardPage> {
  @override
  void initState() {
    super.initState();
    authController.addListener(_atualizarTela);
  }

  @override
  void dispose() {
    authController.removeListener(_atualizarTela);
    super.dispose();
  }

  void _atualizarTela() => setState(() {});

  @override
  Widget build(BuildContext context) {
    // Cada atalho diz quais permissões abrem ele (basta ter UMA da lista).
    // Depois filtramos: só aparece o que a pessoa logada pode usar
    // (o chefe vê tudo). As mesmas 13 permissões da web e do desktop.
    final todosOsAtalhos = <Map<String, dynamic>>[
      {
        "title": "Clientes",
        "permissoes": [Permissao.clientesVer],
        "icon": Icons.people_alt_rounded,
        "color": Colors.blueGrey,
        "page": const ClientesPage(),
      },
      {
        "title": "Cadastro Veículos",
        "permissoes": [Permissao.veiculosGerenciar],
        "icon": Icons.directions_car_filled_rounded,
        "color": Colors.orange,
        "page": const CadastroVeiculoPage(),
      },
      {
        "title": "Frota",
        "permissoes": [Permissao.veiculosVer],
        "icon": Icons.event_available_rounded,
        "color": const Color.fromARGB(255, 46, 125, 50),
        "page": const FrotaPage(),
      },
      {
        "title": "Nova Locação",
        "permissoes": [Permissao.locacoesGerenciar],
        "icon": Icons.vpn_key_rounded,
        "color": const Color.fromARGB(255, 14, 99, 16),
        "page": const LocacaoPage(),
      },
      {
        "title": "Devoluções",
        "permissoes": [Permissao.locacoesGerenciar],
        "icon": Icons.assignment_return_rounded,
        "color": Colors.redAccent,
        "page": const DevolucaoPage(),
      },
      {
        "title": "Relatórios",
        "permissoes": [Permissao.relatorios, Permissao.manutencoes],
        "icon": Icons.bar_chart_rounded,
        "color": Colors.indigo,
        "page": const MenuRelatoriosPage(),
      },
      {
        "title": "Manutenção",
        "permissoes": [Permissao.manutencoes],
        "icon": Icons.build_rounded,
        "color": RoyaleColors.statusManutencao,
        "page": const ManutencaoPage(),
      },
      {
        "title": "Financeiro",
        "permissoes": [Permissao.financeiro],
        "icon": Icons.attach_money_rounded,
        "color": const Color.fromARGB(255, 50, 231, 144),
        "page": const FinancasPage(),
      },
    ];

    final menuItems = todosOsAtalhos
        .where((atalho) => (atalho["permissoes"] as List<String>).any(authController.pode))
        .toList();

    return Scaffold(
      backgroundColor: RoyaleColors.fundoApp,
      appBar: AppBar(
        title: const AnimatedGoldenTitle("ROYALE CARS", fontSize: 24),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: RoyaleColors.azulMarinho),
              accountName: Text(authController.usuario?.nome ?? "Usuário"),
              accountEmail: Text(
                "${authController.usuario?.email ?? ""} · ${authController.usuario?.cargoTexto ?? ""}",
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: RoyaleColors.dourado,
                child: Icon(Icons.person, color: RoyaleColors.azulMarinho),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.groups, color: Colors.lightBlue),
              title: const Text("Sobre Nós"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SobreNosPage()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.lock_outline, color: RoyaleColors.azulMarinho),
              title: const Text("Trocar minha senha"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TrocarSenhaPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Sair da Conta"),
              onTap: () async {
                await authController.sair();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: menuItems.isEmpty
          ? _semAcesso()
          : GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: menuItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              final item = menuItems[index];
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => item["page"])),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item["icon"], size: 45, color: item["color"]),
                      const SizedBox(height: 10),
                      Text(item["title"], style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            },
          ),
      bottomNavigationBar: const RoyaleFooter(),
    );
  }

  /// Conta sem nenhuma permissão liberada: em vez de uma tela vazia,
  /// explica o que fazer.
  Widget _semAcesso() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "Seu usuário ainda não tem acesso a nenhuma área.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "Peça ao responsável pela locadora para liberar suas permissões. "
              "Depois, saia e entre de novo no app.",
              textAlign: TextAlign.center,
              style: TextStyle(color: RoyaleColors.textoMuted),
            ),
          ],
        ),
      ),
    );
  }
}
