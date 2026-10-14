import 'package:flutter/material.dart';
import 'relatorio_page.dart';
import 'manutencao_page.dart';
import 'historico_manutencao_page.dart';
import 'package:royale_cars_location/widgets/animated_golden_title.dart';
import 'package:royale_cars_location/widgets/royale_footer.dart';

class MenuRelatoriosPage extends StatelessWidget {
  const MenuRelatoriosPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Organizado por tipo para facilitar a renderização de ícones e navegação

    final List<Map<String, dynamic>> todosItens = [
      {
        "titulo": "Relatório de Clientes",
        "tipo": "relatorio",
        "restrito": false,
      },
      {
        "titulo": "Relatório de Veículos",
        "tipo": "relatorio",
        "restrito": false,
      },
      {
        "titulo": "Relatório de Locações",
        "tipo": "relatorio",
        "restrito": false,
      },
      {
        "titulo": "Relatório de Devoluções",
        "tipo": "relatorio",
        "restrito": false,
      },

      // Itens restritos que apenas Gerentes/Admins podem ver:
      {
        "titulo": "Relatório de Desempenho",
        "tipo": "relatorio",
        "restrito": true,
      },
      {
        "titulo": "Emitir Laudo Técnico",
        "tipo": "manutencao",
        "restrito": true,
      },
      {
        "titulo": "Histórico de Manutenções",
        "tipo": "historico",
        "restrito": true,
      },
    ];

    // Como agora cada conta representa uma empresa (sem papéis internos
    // de admin/gerente/atendente, igual ao desktop), todos os relatórios
    // ficam visíveis pra quem estiver logado.
    final itensMenu = todosItens;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 247, 245),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 34, 48, 78),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const AnimatedGoldenTitle("Selecione o Relatório", fontSize: 24),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: itensMenu.length,
        itemBuilder: (context, index) {
          final item = itensMenu[index];
          final String titulo = item["titulo"];
          final String tipo = item["tipo"];

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              // Define o ícone ideal dinamicamente com base no tipo do item
              leading: Icon(
                tipo == "manutencao"
                    ? Icons
                          .build_rounded // Chave inglesa para preencher laudo
                    : tipo == "historico"
                    ? Icons
                          .history_edu_rounded // Prancheta/Histórico para ver salvos
                    : Icons.analytics, // Gráfico padrão para estatísticas
                color: tipo == "relatorio"
                    ? Colors.amberAccent
                    : Colors.deepOrangeAccent,
              ),
              title: Text(
                titulo,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Navegação condicional segura baseada no tipo do item clicado
                if (tipo == "manutencao") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManutencaoPage(),
                    ),
                  );
                } else if (tipo == "historico") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HistoricoManutencaoPage(),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RelatorioPage(titulo: titulo),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
      bottomNavigationBar: const RoyaleFooter(),
    );
  }
}
