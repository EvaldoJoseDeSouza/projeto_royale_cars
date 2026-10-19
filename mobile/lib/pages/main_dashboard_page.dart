import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../models/painel.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../utils/permissoes.dart';
import '../utils/validadores.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_footer.dart';
import 'alertas_page.dart';
import 'cadastro_veiculo_page.dart';
import 'clientes_page.dart';
import 'financas_page.dart';
import 'frota_page.dart';
import 'locacao_page.dart';
import 'locacoes_page.dart';
import 'login_page.dart';
import 'manutencao_page.dart';
import 'menu_relatorios_page.dart';
import 'minha_conta_page.dart';
import 'sobre_nos_page.dart';

class MainDashboardPage extends StatefulWidget {
  const MainDashboardPage({super.key});

  @override
  State<MainDashboardPage> createState() => _MainDashboardPageState();
}

/// O resumo do topo do painel: frota, alertas e faturamento do mês.
/// Vem das visões do banco, as MESMAS do Dashboard da web e do desktop.
class _ResumoPainel {
  final SituacaoFrota frota;
  final List<Alerta> alertas;
  final MesFinanceiro? esteMes; // null para quem não pode ver o financeiro

  const _ResumoPainel(this.frota, this.alertas, this.esteMes);
}

class _MainDashboardPageState extends State<MainDashboardPage> {
  late Future<_ResumoPainel> _resumo = _buscarResumo();

  @override
  void initState() {
    super.initState();
    authController.addListener(_atualizarTela);
  }

  /// As 3 perguntas ao banco AO MESMO TEMPO (Future.wait), igual ao desktop.
  Future<_ResumoPainel> _buscarResumo() async {
    final servico = SupabaseService.instance;
    final podeFinanceiro = authController.pode(Permissao.financeiro);

    final respostas = await Future.wait<dynamic>([
      servico.buscarSituacaoFrota(),
      servico.buscarAlertas(),
      podeFinanceiro ? servico.buscarMeses() : Future.value(<MesFinanceiro>[]),
    ]);

    final meses = respostas[2] as List<MesFinanceiro>;
    return _ResumoPainel(
      respostas[0] as SituacaoFrota,
      respostas[1] as List<Alerta>,
      meses.isEmpty ? null : meses.last, // a lista vem do mês mais velho para o mais novo
    );
  }

  /// Busca o resumo de novo (ao voltar de outra tela ou ao puxar para baixo).
  Future<void> _recarregar() async {
    final novo = _buscarResumo();
    setState(() => _resumo = novo);
    try {
      await novo;
    } catch (_) {
      // o erro aparece no próprio quadro do resumo
    }
  }

  /// Abre uma tela e, ao voltar, atualiza os números do painel.
  Future<void> _abrir(Widget tela) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => tela));
    if (mounted) _recarregar();
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
        // A lista com abas: daqui saem a devolução, o cancelamento e o contrato
        "title": "Locações",
        "permissoes": [Permissao.locacoesVer],
        "icon": Icons.assignment_rounded,
        "color": Colors.redAccent,
        "page": const LocacoesPage(),
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
        actions: [
          FutureBuilder<_ResumoPainel>(
            future: _resumo,
            builder: (context, snapshot) {
              final total = snapshot.data?.alertas.length ?? 0;
              return IconButton(
                tooltip: 'Alertas',
                onPressed: () => _abrir(const AlertasPage()),
                icon: Badge(
                  isLabelVisible: total > 0,
                  label: Text('$total'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              );
            },
          ),
        ],
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
              leading: const Icon(Icons.manage_accounts, color: RoyaleColors.azulMarinho),
              title: const Text("Minha conta"),
              onTap: () {
                Navigator.pop(context);
                _abrir(const MinhaContaPage());
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
          : RefreshIndicator(
              onRefresh: _recarregar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _quadroResumo(),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true, // a grade fica do tamanho dela, dentro da lista
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: menuItems.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.3,
                    ),
                    itemBuilder: (context, index) {
                      final item = menuItems[index];
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _abrir(item["page"]),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(item["icon"], size: 40, color: item["color"]),
                              const SizedBox(height: 8),
                              Text(item["title"], style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
      bottomNavigationBar: const RoyaleFooter(),
    );
  }

  /// Um número do resumo (ex.: "5 disponíveis").
  Widget _numero(String valor, String rotulo, Color cor) {
    return Expanded(
      child: Column(
        children: [
          Text(valor, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: cor)),
          Text(rotulo, style: const TextStyle(fontSize: 12, color: RoyaleColors.textoMuted)),
        ],
      ),
    );
  }

  /// O topo do painel: frota, faturamento do mês e os primeiros alertas.
  Widget _quadroResumo() {
    return FutureBuilder<_ResumoPainel>(
      future: _resumo,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: RoyaleColors.azulMarinho)),
          );
        }
        if (snapshot.hasError) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.wifi_off, color: RoyaleColors.statusAlugado),
              title: const Text('Não foi possível carregar o resumo.'),
              subtitle: const Text('Puxe a tela para baixo para tentar de novo.'),
              onTap: _recarregar,
            ),
          );
        }

        final r = snapshot.data!;
        final nome = authController.usuario?.nome.split(' ').first ?? '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Olá, $nome!', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: RoyaleColors.azulMarinho)),
            const SizedBox(height: 10),

            // ----- A frota agora -----
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    _numero('${r.frota.disponiveis}', 'disponíveis', RoyaleColors.statusDisponivel),
                    _numero('${r.frota.alugados}', 'alugados', RoyaleColors.statusAlugado),
                    _numero('${r.frota.emManutencao}', 'na oficina', RoyaleColors.statusManutencao),
                  ],
                ),
              ),
            ),

            // ----- Faturamento do mês (só para quem pode ver o financeiro) -----
            if (r.esteMes != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.trending_up, color: RoyaleColors.statusDisponivel),
                  title: Text('Faturamento do mês: ${moeda(r.esteMes!.faturamento)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${r.esteMes!.alugueis} aluguel(éis) finalizado(s) • '
                      'manutenção ${moeda(r.esteMes!.manutencao)}'),
                ),
              ),

            // ----- Os primeiros alertas -----
            if (r.alertas.isNotEmpty)
              Card(
                child: Column(
                  children: [
                    for (final alerta in r.alertas.take(3))
                      ListTile(
                        dense: true,
                        leading: Icon(AlertasPage.visual(alerta.tipo).$2, color: AlertasPage.visual(alerta.tipo).$1),
                        title: Text(alerta.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(alerta.detalhe, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () async {
                          if (await AlertasPage.abrir(context, alerta)) _recarregar();
                        },
                      ),
                    TextButton(
                      onPressed: () => _abrir(const AlertasPage()),
                      child: Text('Ver todos os alertas (${r.alertas.length})'),
                    ),
                  ],
                ),
              )
            else
              const Card(
                child: ListTile(
                  leading: Icon(Icons.check_circle, color: RoyaleColors.statusDisponivel),
                  title: Text('Nenhum alerta. Está tudo em dia!'),
                ),
              ),
          ],
        );
      },
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
