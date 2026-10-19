import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../models/manutencao.dart';
import '../theme/colors.dart';
import '../utils/permissoes.dart';
import '../utils/validadores.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/checklist_vistoria.dart';
import '../widgets/royale_footer.dart';
import 'enviar_manutencao_page.dart';
import 'liberar_manutencao_page.dart';

/// Manutenção, com as MESMAS abas da web: "Na oficina" (com o botão
/// Liberar) e "Concluídas" (o histórico, com serviço e custo).
///
/// O antigo "Laudo Técnico" do celular virou a VISTORIA (checklist)
/// que vai junto quando o carro é enviado para a oficina.
class ManutencaoPage extends StatefulWidget {
  /// 0 = Na oficina, 1 = Concluídas
  final int abaInicial;

  const ManutencaoPage({super.key, this.abaInicial = 0});

  @override
  State<ManutencaoPage> createState() => _ManutencaoPageState();
}

class _ManutencaoPageState extends State<ManutencaoPage> {
  @override
  void initState() {
    super.initState();
    _recarregar();
  }

  Future<void> _recarregar() async {
    try {
      await manutencaoController.carregar();
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: RoyaleColors.statusAlugado,
          content: Text('Não foi possível carregar as manutenções. Puxe a lista para tentar de novo.'),
        ),
      );
    }
  }

  Future<void> _abrirTela(Widget tela) async {
    final mudou = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => tela));
    if (mudou == true) await frotaController.recarregar(); // o status do carro mudou
  }

  /// A lista de uma aba (com "puxar para atualizar" e aviso de vazia).
  Widget _lista(List<Manutencao> itens, String vazia, Widget Function(Manutencao) cartao) {
    return RefreshIndicator(
      onRefresh: _recarregar,
      child: itens.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Text(manutencaoController.isLoading ? 'Carregando...' : vazia,
                      style: const TextStyle(color: Colors.grey)),
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: itens.map(cartao).toList(),
            ),
    );
  }

  Widget _cartaoNaOficina(Manutencao m, bool podeLiberar) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${m.nomeVeiculo} (${m.placaFormatada})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(m.defeito),
            const SizedBox(height: 4),
            Text(
              'Entrou em ${dataBr(m.dataEntrada)} (há ${m.diasParado} dia(s))'
              '${m.oficina != null ? ' • ${m.oficina}' : ''}',
              style: const TextStyle(color: RoyaleColors.textoMuted, fontSize: 12.5),
            ),
            if (m.previsaoLiberacao != null)
              Text(
                'Previsão: ${dataBr(m.previsaoLiberacao!)}${m.previsaoVencida ? ' (já passou!)' : ''}',
                style: TextStyle(
                  color: m.previsaoVencida ? RoyaleColors.statusAlugado : RoyaleColors.textoMuted,
                  fontSize: 12.5,
                  fontWeight: m.previsaoVencida ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            if (m.locacaoId != null)
              Text('Voltou com defeito do aluguel #${m.locacaoId}',
                  style: const TextStyle(color: RoyaleColors.textoMuted, fontSize: 12.5)),
            const SizedBox(height: 6),
            ChecklistVistoria(manutencao: m),
            if (podeLiberar) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => _abrirTela(LiberarManutencaoPage(manutencao: m)),
                  icon: const Icon(Icons.check),
                  label: const Text('Liberar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cartaoConcluida(Manutencao m) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        title: Text('${m.nomeVeiculo} (${m.placaFormatada})', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${dataBr(m.dataEntrada)} a ${m.dataLiberacao != null ? dataBr(m.dataLiberacao!) : '?'}'
          ' • ${moeda(m.custo ?? 0)}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Defeito: ${m.defeito}'),
          const SizedBox(height: 4),
          Text('Serviço: ${m.servicoRealizado ?? '-'}'),
          if (m.oficina != null) Text('Oficina: ${m.oficina}'),
          Text('${m.diasParado} dia(s) parado'),
          const SizedBox(height: 6),
          ChecklistVistoria(manutencao: m),
          const SizedBox(height: 6),
          Text(
            'Enviado por ${m.abertaPor ?? '-'} • liberado por ${m.concluidaPor ?? '-'}',
            style: const TextStyle(color: RoyaleColors.textoMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final podeMexer = authController.pode(Permissao.manutencoes);

    return DefaultTabController(
      length: 2,
      initialIndex: widget.abaInicial,
      child: ListenableBuilder(
        listenable: manutencaoController,
        builder: (context, child) {
          final naOficina = manutencaoController.naOficina;
          final custoTotal = manutencaoController.concluidas.fold<double>(0, (soma, m) => soma + (m.custo ?? 0));

          return Scaffold(
            appBar: AppBar(
              title: const AnimatedGoldenTitle('Manutenção', fontSize: 24),
              bottom: TabBar(
                labelColor: RoyaleColors.dourado,
                unselectedLabelColor: Colors.white70,
                indicatorColor: RoyaleColors.dourado,
                tabs: [
                  Tab(text: 'Na oficina (${naOficina.length})'),
                  const Tab(text: 'Concluídas'),
                ],
              ),
            ),
            floatingActionButton: podeMexer
                ? FloatingActionButton.extended(
                    backgroundColor: RoyaleColors.dourado,
                    foregroundColor: RoyaleColors.azulMarinho,
                    onPressed: () => _abrirTela(const EnviarManutencaoPage()),
                    icon: const Icon(Icons.build),
                    label: const Text('Enviar para oficina'),
                  )
                : null,
            body: TabBarView(
              children: [
                _lista(naOficina, 'Nenhum carro na oficina.', (m) => _cartaoNaOficina(m, podeMexer)),
                Column(
                  children: [
                    if (manutencaoController.concluidas.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: RoyaleColors.azulMarinho,
                        child: Text(
                          '${manutencaoController.concluidas.length} manutenção(ões) • custo total ${moeda(custoTotal)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    Expanded(child: _lista(manutencaoController.concluidas, 'Nenhuma manutenção concluída.', _cartaoConcluida)),
                  ],
                ),
              ],
            ),
            bottomNavigationBar: const RoyaleFooter(),
          );
        },
      ),
    );
  }
}
