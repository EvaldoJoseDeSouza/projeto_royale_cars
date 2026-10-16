import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../models/veiculo.dart';
import '../theme/colors.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_footer.dart';
import 'cadastro_veiculo_page.dart';

class FrotaPage extends StatelessWidget {
  const FrotaPage({super.key});

  Color _corStatus(String status) {
    switch (status) {
      case Veiculo.statusDisponivel:
        return RoyaleColors.statusDisponivel;
      case Veiculo.statusManutencao:
        return RoyaleColors.statusManutencao;
      default:
        return RoyaleColors.statusAlugado;
    }
  }

  Future<void> _arquivar(BuildContext context, Veiculo veiculo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arquivar veículo?'),
        content: Text('O ${veiculo.marca} ${veiculo.modelo} (${veiculo.placa}) deixará de aparecer na frota ativa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Arquivar')),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await frotaController.arquivarVeiculo(veiculo.id!);
    } catch (erro) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: RoyaleColors.statusAlugado,
            content: Text(erro.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: frotaController,
      builder: (context, child) {
        final listaVeiculos = frotaController.veiculos;

        return Scaffold(
          appBar: AppBar(
            title: const AnimatedGoldenTitle("Frota", fontSize: 24),
            actions: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text("${listaVeiculos.length} veículo(s)",
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: RoyaleColors.dourado,
            foregroundColor: RoyaleColors.azulMarinho,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CadastroVeiculoPage()),
            ),
            child: const Icon(Icons.add),
          ),
          body: listaVeiculos.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car_filled_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("Nenhum veículo na frota.", style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: listaVeiculos.length,
                  itemBuilder: (context, index) {
                    final veiculo = listaVeiculos[index];
                    final cor = _corStatus(veiculo.status);

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
                          child: const Icon(Icons.directions_car, color: Colors.white),
                        ),
                        title: Text("${veiculo.marca} ${veiculo.modelo}",
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "Placa: ${veiculo.placa}\n"
                            "Diária: R\$ ${veiculo.diaria.toStringAsFixed(2)}  •  ${veiculo.quilometragem} km",
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(20)),
                              child: Text(veiculo.status,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (valor) {
                                if (valor == 'editar') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => CadastroVeiculoPage(veiculoParaEditar: veiculo)),
                                  );
                                } else if (valor == 'arquivar') {
                                  _arquivar(context, veiculo);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: 'editar', child: Text('Editar')),
                                PopupMenuItem(value: 'arquivar', child: Text('Arquivar')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          bottomNavigationBar: const RoyaleFooter(),
        );
      },
    );
  }
}
