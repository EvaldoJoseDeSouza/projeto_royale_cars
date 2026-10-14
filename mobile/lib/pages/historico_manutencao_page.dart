import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import '../dependencies.dart';
import '../models/laudo_manutencao.dart';
import 'package:royale_cars_location/widgets/animated_golden_title.dart';
import 'package:royale_cars_location/widgets/royale_footer.dart';

class HistoricoManutencaoPage extends StatelessWidget {
  const HistoricoManutencaoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 247, 245),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 34, 48, 78),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: const AnimatedGoldenTitle("Laudos Técnicos", fontSize: 24),
      ),
      body: ListenableBuilder(
        listenable: manutencaoController,
        builder: (context, child) {
          final listaLaudos = manutencaoController.laudos;

          if (listaLaudos.isEmpty) {
            return _buildListaVazia();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: listaLaudos.length,
            itemBuilder: (context, index) {
              // Mostra os laudos mais recentes primeiro
              final laudo = listaLaudos.reversed.toList()[index];
              return _buildCardLaudo(context, laudo);
            },
          );
        },
      ),
      bottomNavigationBar: const RoyaleFooter(),
    );
  }

  // Widget para renderizar cada laudo na lista
  Widget _buildCardLaudo(BuildContext context, LaudoManutencao laudo) {
    final String dataFormatada = DateFormat('dd/MM/yyyy HH:mm').format(laudo.dataRegistro);
    
    // Contagem de quantos itens passaram no checklist
    int itensAprovados = 0;
    if (laudo.motorOk) itensAprovados++;
    if (laudo.freiosOk) itensAprovados++;
    if (laudo.pneusOk) itensAprovados++;
    if (laudo.oleoOk) itensAprovados++;

    final bool aprovado100 = itensAprovados == 4;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: aprovado100 ? Colors.green.shade100 : Colors.orange.shade100,
          child: Icon(
            aprovado100 ? Icons.check_circle_rounded : Icons.warning_rounded,
            color: aprovado100 ? Colors.green.shade800 : Colors.orange.shade800,
          ),
        ),
        title: Text(
          "Placa: ${laudo.placa}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text("Inspeção: $dataFormatada\nStatus: $itensAprovados/4 itens OK"),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Checklist Detalhado:",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 34, 48, 78)),
                ),
                const SizedBox(height: 8),
                _buildItemChecklist("Motor e Injeção", laudo.motorOk),
                _buildItemChecklist("Sistema de Freios", laudo.freiosOk),
                _buildItemChecklist("Pneus e Estepe", laudo.pneusOk),
                _buildItemChecklist("Óleo e Fluidos", laudo.oleoOk),
                const SizedBox(height: 12),
                const Text(
                  "Diagnóstico e Observações:",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 34, 48, 78)),
                ),
                const SizedBox(height: 4),
                Text(
                  laudo.observacoes.trim().isEmpty 
                      ? "Nenhuma observação inserida pelo técnico." 
                      : laudo.observacoes,
                  style: TextStyle(color: Colors.grey.shade800, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildItemChecklist(String texto, bool isOk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.done : Icons.close,
            color: isOk ? Colors.green : Colors.red,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(texto, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildListaVazia() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_rounded, size: 60, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              "Histórico Vazio",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            SizedBox(height: 6),
            Text(
              "Nenhum laudo técnico ou relatório de manutenção foi emitido até o momento.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}