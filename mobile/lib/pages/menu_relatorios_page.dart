import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../utils/permissoes.dart';
import 'relatorio_page.dart';
import 'manutencao_page.dart';
import 'package:royale_cars_location/widgets/animated_golden_title.dart';
import 'package:royale_cars_location/widgets/royale_footer.dart';

class MenuRelatoriosPage extends StatelessWidget {
  const MenuRelatoriosPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Cada item diz qual permissão é preciso ter para vê-lo. Antes havia
    // um campo "restrito" que ninguém conferia; agora vale a permissão de
    // verdade, a mesma da web e do desktop.
    final List<Map<String, dynamic>> todosItens = [
      {"titulo": "Relatório de Clientes", "tipo": "relatorio", "permissao": Permissao.relatorios},
      {"titulo": "Relatório de Veículos", "tipo": "relatorio", "permissao": Permissao.relatorios},
      {"titulo": "Relatório de Locações", "tipo": "relatorio", "permissao": Permissao.relatorios},
      {"titulo": "Relatório de Devoluções", "tipo": "relatorio", "permissao": Permissao.relatorios},
      {"titulo": "Relatório de Desempenho", "tipo": "relatorio", "permissao": Permissao.relatorios},
      // O histórico de manutenções (com o checklist e o custo) também aparece aqui
      {"titulo": "Histórico de Manutenções", "tipo": "historico", "permissao": Permissao.manutencoes},
    ];

    final itensMenu = todosItens.where((item) => authController.pode(item["permissao"])).toList();

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
                tipo == "historico"
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
                if (tipo == "historico") {
                  // Abre a Manutenção direto na aba "Concluídas"
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManutencaoPage(abaInicial: 1),
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
