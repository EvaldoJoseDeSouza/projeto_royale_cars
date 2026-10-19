import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../models/cliente.dart';
import '../theme/colors.dart';
import '../utils/permissoes.dart';
import '../utils/validadores.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_footer.dart';
import '../widgets/selo_cnh.dart';
import 'cadastro_cliente_page.dart';
import 'clientes_arquivados_page.dart';

/// Lista de clientes com busca, edição e arquivamento.
/// Os botões aparecem conforme as permissões de quem está logado.
class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  String _busca = '';

  void _avisar(String mensagem, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: cor, content: Text(mensagem)));
  }

  Future<void> _arquivar(Cliente cliente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arquivar cliente?'),
        content: Text('${cliente.nome} deixará de aparecer na lista. O histórico de locações continua guardado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Arquivar')),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      final mensagem = await clienteController.arquivarCliente(cliente.id!);
      _avisar(mensagem, RoyaleColors.statusDisponivel);
    } catch (erro) {
      // Ex.: "O cliente Ana tem aluguel em andamento. Registre a devolução antes de arquivar."
      _avisar(erro.toString().replaceFirst('Exception: ', ''), RoyaleColors.statusAlugado);
    }
  }

  /// A busca aceita nome ("ana") ou CPF com ou sem pontos ("529.982" ou "529982").
  bool _combina(Cliente cliente) {
    final termo = _busca.trim().toLowerCase();
    if (termo.isEmpty) return true;

    final numeros = soDigitos(termo);
    return cliente.nome.toLowerCase().contains(termo) || (numeros.isNotEmpty && cliente.cpf.contains(numeros));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: clienteController,
      builder: (context, child) {
        final lista = clienteController.clientes.where(_combina).toList();

        // O que esta pessoa pode fazer aqui (o resto fica escondido)
        final podeEditar = authController.pode(Permissao.clientesGerenciar);
        final podeArquivar = authController.pode(Permissao.clientesArquivar);

        return Scaffold(
          appBar: AppBar(
            title: const AnimatedGoldenTitle('Clientes', fontSize: 24),
            actions: [
              IconButton(
                tooltip: 'Clientes arquivados',
                icon: const Icon(Icons.inventory_2_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ClientesArquivadosPage()),
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
                // Puxar a lista para baixo recarrega do banco
                child: RefreshIndicator(
                  onRefresh: clienteController.carregarClientes,
                  child: lista.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Text(
                                clienteController.isLoading ? 'Carregando...' : 'Nenhum cliente encontrado.',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
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
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('CPF: ${cliente.cpfFormatado}  •  ${cliente.telefoneFormatado}'),
                                    const SizedBox(height: 4),
                                    SeloCnh(cliente: cliente),
                                  ],
                                ),
                                trailing: !podeEditar && !podeArquivar
                                    ? null
                                    : PopupMenuButton<String>(
                                        onSelected: (valor) {
                                          if (valor == 'editar') {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) => CadastroClientePage(clienteParaEditar: cliente)),
                                            );
                                          } else if (valor == 'arquivar') {
                                            _arquivar(cliente);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          if (podeEditar) const PopupMenuItem(value: 'editar', child: Text('Editar')),
                                          if (podeArquivar) const PopupMenuItem(value: 'arquivar', child: Text('Arquivar')),
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
