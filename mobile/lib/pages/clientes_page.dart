import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../theme/colors.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_footer.dart';
import 'cadastro_cliente_page.dart';

/// Lista de clientes com busca, edição e arquivamento — antes só
/// existia a tela de cadastro, sem nenhuma forma de ver ou gerenciar
/// os clientes já cadastrados.
class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  String _busca = '';

  Future<void> _arquivar(BuildContext context, int idCliente) async {
    final idEmpresa = authController.idEmpresa;
    if (idEmpresa == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arquivar cliente?'),
        content: const Text('Ele deixará de aparecer na lista de clientes ativos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Arquivar')),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await clienteController.arquivarCliente(idCliente, idEmpresa);
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
      listenable: clienteController,
      builder: (context, child) {
        final termo = _busca.toLowerCase();
        final lista = clienteController.clientes
            .where((c) => c.nome.toLowerCase().contains(termo) || c.cpf.contains(termo))
            .toList();

        return Scaffold(
          appBar: AppBar(title: const AnimatedGoldenTitle('Clientes', fontSize: 24)),
          floatingActionButton: FloatingActionButton(
            backgroundColor: RoyaleColors.dourado,
            foregroundColor: RoyaleColors.azulMarinho,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CadastroClientePage()),
            ),
            child: const Icon(Icons.add),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nome ou CPF...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _busca = v),
                ),
              ),
              Expanded(
                child: lista.isEmpty
                    ? const Center(
                        child: Text('Nenhum cliente encontrado.', style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: lista.length,
                        itemBuilder: (context, index) {
                          final cliente = lista[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: RoyaleColors.azulMarinho,
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                              title: Text(cliente.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('CPF: ${cliente.cpf}  •  ${cliente.telefone}'),
                              trailing: PopupMenuButton<String>(
                                onSelected: (valor) {
                                  if (valor == 'editar') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => CadastroClientePage(clienteParaEditar: cliente)),
                                    );
                                  } else if (valor == 'arquivar') {
                                    _arquivar(context, cliente.id!);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(value: 'editar', child: Text('Editar')),
                                  PopupMenuItem(value: 'arquivar', child: Text('Arquivar')),
                                ],
                              ),
                            ),
                          );
                        },
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
