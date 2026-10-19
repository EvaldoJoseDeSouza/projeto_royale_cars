import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../models/locacao.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../utils/permissoes.dart';
import '../utils/validadores.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_footer.dart';
import '../widgets/selo_status_locacao.dart';
import 'locacao_detalhes_page.dart';
import 'locacao_page.dart';

/// Locações, com as MESMAS abas da web: Em andamento, Atrasados,
/// Finalizados e Cancelados. Tocar num aluguel abre os detalhes, onde
/// ficam a devolução, o cancelamento e o contrato.
class LocacoesPage extends StatefulWidget {
  const LocacoesPage({super.key});

  @override
  State<LocacoesPage> createState() => _LocacoesPageState();
}

class _LocacoesPageState extends State<LocacoesPage> {
  final _abas = SupabaseService.abasLocacao.keys.toList();
  String _busca = '';

  /// Cada aba carrega a sua lista. Guardamos o "pedido" de cada uma
  /// (Future) para não buscar de novo toda vez que a tela redesenha.
  final Map<String, Future<List<Locacao>>> _listas = {};

  Future<List<Locacao>> _lista(String aba) => _listas[aba] ??= locacaoController.listar(aba);

  /// Esquece as listas guardadas e busca de novo (depois de devolver,
  /// cancelar, ou ao puxar a lista para baixo).
  Future<void> _recarregar() async {
    setState(_listas.clear);
    await Future.wait(_abas.map(_lista));
  }

  Future<void> _abrir(Locacao locacao) async {
    final mudou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => LocacaoDetalhesPage(locacao: locacao)),
    );
    if (mudou == true) _recarregar();
  }

  Future<void> _novaLocacao() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const LocacaoPage()));
    _recarregar();
  }

  /// A busca aceita cliente, carro, placa ou número do aluguel.
  bool _combina(Locacao l) {
    final termo = _busca.trim().toLowerCase();
    if (termo.isEmpty) return true;
    final codigo = limparCodigo(termo);
    return l.nomeCliente.toLowerCase().contains(termo) ||
        l.nomeVeiculo.toLowerCase().contains(termo) ||
        (codigo.isNotEmpty && l.placa.contains(codigo)) ||
        '${l.id}' == termo.replaceAll('#', '');
  }

  Widget _conteudoDaAba(String aba) {
    return FutureBuilder<List<Locacao>>(
      future: _lista(aba),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: RoyaleColors.azulMarinho));
        }

        final mensagemVazia = snapshot.hasError
            ? 'Não foi possível carregar. Puxe para baixo para tentar de novo.'
            : 'Nenhum aluguel aqui.';
        final lista = (snapshot.data ?? []).where(_combina).toList();

        return RefreshIndicator(
          onRefresh: _recarregar,
          child: lista.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 80),
                    Center(child: Text(mensagemVazia, style: const TextStyle(color: Colors.grey))),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: lista.length,
                  itemBuilder: (context, index) {
                    final l = lista[index];
                    final datas = l.dataDevolucao != null
                        ? '${dataBr(l.dataRetirada)} a ${dataBr(l.dataDevolucao!)}'
                        : '${dataBr(l.dataRetirada)} • prevista ${dataBr(l.dataPrevista)}';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        onTap: () => _abrir(l),
                        title: Text('#${l.id} • ${l.nomeCliente}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${l.nomeVeiculo} (${l.placaFormatada})'),
                            Text(datas),
                            const SizedBox(height: 4),
                            SeloStatusLocacao(statusExibicao: l.statusExibicao),
                          ],
                        ),
                        trailing: Text(moeda(l.valorTotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final podeRegistrar = authController.pode(Permissao.locacoesGerenciar);

    return DefaultTabController(
      length: _abas.length,
      child: Scaffold(
        appBar: AppBar(
          title: const AnimatedGoldenTitle('Locações', fontSize: 24),
          bottom: TabBar(
            isScrollable: true,
            labelColor: RoyaleColors.dourado,
            unselectedLabelColor: Colors.white70,
            indicatorColor: RoyaleColors.dourado,
            tabs: [for (final aba in _abas) Tab(text: aba)],
          ),
        ),
        floatingActionButton: podeRegistrar
            ? FloatingActionButton.extended(
                backgroundColor: RoyaleColors.dourado,
                foregroundColor: RoyaleColors.azulMarinho,
                onPressed: _novaLocacao,
                icon: const Icon(Icons.add),
                label: const Text('Nova locação'),
              )
            : null,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar cliente, carro, placa ou nº...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _busca = v),
              ),
            ),
            Expanded(child: TabBarView(children: [for (final aba in _abas) _conteudoDaAba(aba)])),
          ],
        ),
        bottomNavigationBar: const RoyaleFooter(),
      ),
    );
  }
}
