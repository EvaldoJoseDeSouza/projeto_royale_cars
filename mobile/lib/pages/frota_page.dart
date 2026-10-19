import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../models/veiculo.dart';
import '../theme/colors.dart';
import '../utils/permissoes.dart';
import '../utils/validadores.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/foto_veiculo.dart';
import '../widgets/royale_footer.dart';
import '../widgets/selo_status_veiculo.dart';
import 'cadastro_veiculo_page.dart';
import 'frota_arquivada_page.dart';

/// A frota ativa, com foto, status e busca por marca, modelo ou placa.
/// Os botões aparecem conforme as permissões de quem está logado.
class FrotaPage extends StatefulWidget {
  const FrotaPage({super.key});

  @override
  State<FrotaPage> createState() => _FrotaPageState();
}

class _FrotaPageState extends State<FrotaPage> {
  String _busca = '';

  void _avisar(String mensagem, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: cor, content: Text(mensagem)));
  }

  Future<void> _arquivar(Veiculo veiculo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arquivar veículo?'),
        content: Text('O ${veiculo.nomeCompleto} (${veiculo.placaFormatada}) deixará de aparecer na frota. '
            'O histórico de locações continua guardado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Arquivar')),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      final mensagem = await frotaController.arquivarVeiculo(veiculo.id!);
      _avisar(mensagem, RoyaleColors.statusDisponivel);
    } catch (erro) {
      // Ex.: "Só é possível arquivar veículos disponíveis. Este está: Alugado."
      _avisar(erro.toString().replaceFirst('Exception: ', ''), RoyaleColors.statusAlugado);
    }
  }

  /// A busca aceita marca, modelo ou placa (com ou sem hífen).
  bool _combina(Veiculo veiculo) {
    final termo = _busca.trim().toLowerCase();
    if (termo.isEmpty) return true;

    final codigo = limparCodigo(termo);
    return veiculo.nomeCompleto.toLowerCase().contains(termo) ||
        (codigo.isNotEmpty && veiculo.placa.contains(codigo));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: frotaController,
      builder: (context, child) {
        final listaVeiculos = frotaController.veiculos.where(_combina).toList();

        // O que esta pessoa pode fazer aqui (o resto fica escondido)
        final podeEditar = authController.pode(Permissao.veiculosGerenciar);
        final podeArquivar = authController.pode(Permissao.veiculosArquivar);

        return Scaffold(
          appBar: AppBar(
            title: const AnimatedGoldenTitle("Frota", fontSize: 24),
            actions: [
              IconButton(
                tooltip: 'Veículos arquivados',
                icon: const Icon(Icons.inventory_2_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FrotaArquivadaPage()),
                ),
              ),
            ],
          ),
          floatingActionButton: !podeEditar
              ? null
              : FloatingActionButton(
                  backgroundColor: RoyaleColors.dourado,
                  foregroundColor: RoyaleColors.azulMarinho,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CadastroVeiculoPage()),
                  ),
                  child: const Icon(Icons.add),
                ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por marca, modelo ou placa...',
                    prefixIcon: const Icon(Icons.search),
                    suffixText: '${listaVeiculos.length} veículo(s)',
                  ),
                  onChanged: (v) => setState(() => _busca = v),
                ),
              ),
              Expanded(
                // Puxar a lista para baixo recarrega do banco
                child: RefreshIndicator(
                  onRefresh: frotaController.carregarVeiculos,
                  child: listaVeiculos.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 80),
                            const Icon(Icons.directions_car_filled_outlined, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                frotaController.isLoading ? 'Carregando...' : 'Nenhum veículo encontrado.',
                                style: const TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: listaVeiculos.length,
                          itemBuilder: (context, index) {
                            final veiculo = listaVeiculos[index];

                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: FotoVeiculo(veiculo: veiculo),
                                title: Text('${veiculo.nomeCompleto} ${veiculo.ano}',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Placa: ${veiculo.placaFormatada}  •  ${veiculo.quilometragem} km'),
                                      Text('Diária: ${moeda(veiculo.valorDiaria)}'),
                                      const SizedBox(height: 6),
                                      SeloStatusVeiculo(status: veiculo.status),
                                    ],
                                  ),
                                ),
                                trailing: !podeEditar && !podeArquivar
                                    ? null
                                    : PopupMenuButton<String>(
                                        onSelected: (valor) {
                                          if (valor == 'editar') {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) => CadastroVeiculoPage(veiculoParaEditar: veiculo)),
                                            );
                                          } else if (valor == 'arquivar') {
                                            _arquivar(veiculo);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          if (podeEditar) const PopupMenuItem(value: 'editar', child: Text('Editar')),
                                          // Só carro Disponível pode ser arquivado (regra do banco)
                                          if (podeArquivar && veiculo.isDisponivel)
                                            const PopupMenuItem(value: 'arquivar', child: Text('Arquivar')),
                                        ],
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: const RoyaleFooter(),
        );
      },
    );
  }
}
