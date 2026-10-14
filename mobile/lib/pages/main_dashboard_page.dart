import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../theme/colors.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_footer.dart';
import 'cadastro_veiculo_page.dart';
import 'clientes_page.dart';
import 'contato_page.dart';
import 'devolucao_page.dart';
import 'financas_page.dart';
import 'frota_page.dart';
import 'locacao_page.dart';
import 'login_page.dart';
import 'manutencao_page.dart';
import 'menu_relatorios_page.dart';
import 'sobre_nos_page.dart';

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
    // Sem sistema de papéis interno (igual ao desktop: cada conta é
    // uma empresa só) — todos os módulos ficam visíveis pra quem
    // estiver logado.
    final menuItems = <Map<String, dynamic>>[
      {
        "title": "Clientes",
        "icon": Icons.people_alt_rounded,
        "color": Colors.blueGrey,
        "page": const ClientesPage(),
      },
      {
        "title": "Cadastro Veículos",
        "icon": Icons.directions_car_filled_rounded,
        "color": Colors.orange,
        "page": const CadastroVeiculoPage(),
      },
      {
        "title": "Frota",
        "icon": Icons.event_available_rounded,
        "color": const Color.fromARGB(255, 46, 125, 50),
        "page": const FrotaPage(),
      },
      {
        "title": "Nova Locação",
        "icon": Icons.vpn_key_rounded,
        "color": const Color.fromARGB(255, 14, 99, 16),
        "page": const LocacaoPage(),
      },
      {
        "title": "Devoluções",
        "icon": Icons.assignment_return_rounded,
        "color": Colors.redAccent,
        "page": const DevolucaoPage(),
      },
      {
        "title": "Relatórios",
        "icon": Icons.bar_chart_rounded,
        "color": Colors.indigo,
        "page": const MenuRelatoriosPage(),
      },
      {
        "title": "Manutenção",
        "icon": Icons.build_rounded,
        "color": RoyaleColors.statusManutencao,
        "page": const ManutencaoPage(),
      },
      {
        "title": "Finanças",
        "icon": Icons.attach_money_rounded,
        "color": const Color.fromARGB(255, 50, 231, 144),
        "page": const FinancasPage(),
      },
    ];

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
              accountName: Text(authController.usuarioLogado?.username ?? "Usuário"),
              accountEmail: Text(authController.usuarioLogado?.email ?? ""),
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
            ListTile(
              leading: const Icon(Icons.contact_support_rounded, color: Colors.teal),
              title: const Text("Contato"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ContatoPage()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Sair da Conta"),
              onTap: () {
                authController.logout();
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
      body: GridView.builder(
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
}
