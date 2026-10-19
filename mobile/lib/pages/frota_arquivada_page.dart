import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../models/veiculo.dart';
import '../theme/colors.dart';
import '../utils/permissoes.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/foto_veiculo.dart';
import '../widgets/royale_footer.dart';

/// Veículos arquivados (a mesma tela da web e do desktop).
/// Arquivar não apaga nada: daqui o carro volta para a frota como
/// Disponível, com todo o histórico.
class FrotaArquivadaPage extends StatefulWidget {
  const FrotaArquivadaPage({super.key});

  @override
  State<FrotaArquivadaPage> createState() => _FrotaArquivadaPageState();
}

class _FrotaArquivadaPageState extends State<FrotaArquivadaPage> {
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      await frotaController.carregarVeiculosArquivados();
      if (mounted) setState(() => _erro = null);
    } catch (erro) {
      if (mounted) setState(() => _erro = 'Não foi possível carregar. Puxe a lista para baixo para tentar de novo.');
    }
  }

  Future<void> _reativar(Veiculo veiculo) async {
    try {
      final mensagem = await frotaController.reativarVeiculo(veiculo.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: RoyaleColors.statusDisponivel, content: Text(mensagem)),
      );
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: RoyaleColors.statusAlugado,
          content: Text(erro.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final podeReativar = authController.pode(Permissao.veiculosArquivar);

    return ListenableBuilder(
      listenable: frotaController,
      builder: (context, child) {
        final lista = frotaController.veiculosArquivados;

        return Scaffold(
          appBar: AppBar(title: const AnimatedGoldenTitle('Veículos arquivados', fontSize: 22)),
          body: RefreshIndicator(
            onRefresh: _carregar,
            child: lista.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      Center(
                        child: Text(_erro ?? 'Nenhum veículo arquivado.', style: const TextStyle(color: Colors.grey)),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: lista.length,
                    itemBuilder: (context, index) {
                      final veiculo = lista[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Opacity(opacity: 0.5, child: FotoVeiculo(veiculo: veiculo)),
                          title: Text('${veiculo.nomeCompleto} ${veiculo.ano}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Placa: ${veiculo.placaFormatada}'),
                          trailing: podeReativar
                              ? TextButton(onPressed: () => _reativar(veiculo), child: const Text('Reativar'))
                              : null,
                        ),
                      );
                    },
                  ),
          ),
          bottomNavigationBar: const RoyaleFooter(),
        );
      },
    );
  }
}
