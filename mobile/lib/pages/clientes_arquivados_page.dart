import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../models/cliente.dart';
import '../theme/colors.dart';
import '../utils/permissoes.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_footer.dart';
import '../widgets/selo_cnh.dart';

/// Clientes arquivados (a mesma tela da web e do desktop).
/// Arquivar não apaga nada: daqui dá para trazer o cadastro de volta,
/// com todos os dados e o histórico de locações.
class ClientesArquivadosPage extends StatefulWidget {
  const ClientesArquivadosPage({super.key});

  @override
  State<ClientesArquivadosPage> createState() => _ClientesArquivadosPageState();
}

class _ClientesArquivadosPageState extends State<ClientesArquivadosPage> {
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      await clienteController.carregarClientesArquivados();
      if (mounted) setState(() => _erro = null);
    } catch (erro) {
      if (mounted) setState(() => _erro = 'Não foi possível carregar. Puxe a lista para baixo para tentar de novo.');
    }
  }

  Future<void> _reativar(Cliente cliente) async {
    try {
      final mensagem = await clienteController.reativarCliente(cliente.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cliente.cnhVencida ? RoyaleColors.statusManutencao : RoyaleColors.statusDisponivel,
          content: Text(mensagem),
        ),
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
    final podeReativar = authController.pode(Permissao.clientesArquivar);

    return ListenableBuilder(
      listenable: clienteController,
      builder: (context, child) {
        final lista = clienteController.clientesArquivados;

        return Scaffold(
          appBar: AppBar(title: const AnimatedGoldenTitle('Clientes arquivados', fontSize: 22)),
          body: RefreshIndicator(
            onRefresh: _carregar,
            child: lista.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      Center(
                        child: Text(_erro ?? 'Nenhum cliente arquivado.', style: const TextStyle(color: Colors.grey)),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: lista.length,
                    itemBuilder: (context, index) {
                      final cliente = lista[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person_off_outlined, color: Colors.white),
                          ),
                          title: Text(cliente.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CPF: ${cliente.cpfFormatado}'),
                              const SizedBox(height: 4),
                              SeloCnh(cliente: cliente),
                            ],
                          ),
                          trailing: podeReativar
                              ? TextButton(onPressed: () => _reativar(cliente), child: const Text('Reativar'))
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
