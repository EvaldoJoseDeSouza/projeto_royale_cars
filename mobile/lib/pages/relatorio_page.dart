import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../dependencies.dart';
import '../models/veiculo.dart';
import '../theme/colors.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_footer.dart';

/// Relatórios do sistema — Clientes, Veículos, Locações, Devoluções
/// (histórico de locações concluídas) e Desempenho (ocupação da frota).
class RelatorioPage extends StatefulWidget {
  final String titulo;

  const RelatorioPage({super.key, required this.titulo});

  @override
  State<RelatorioPage> createState() => _RelatorioPageState();
}

class _RelatorioPageState extends State<RelatorioPage> {
  final _formatoData = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final idEmpresa = authController.idEmpresa;
    if (idEmpresa != null && widget.titulo == 'Relatório de Devoluções') {
      locacaoController.carregarHistorico(idEmpresa);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([clienteController, frotaController, locacaoController]),
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(title: AnimatedGoldenTitle(widget.titulo, fontSize: 22)),
          body: SingleChildScrollView(padding: const EdgeInsets.all(12), child: _conteudo()),
          bottomNavigationBar: const RoyaleFooter(),
        );
      },
    );
  }

  Widget _conteudo() {
    switch (widget.titulo) {
      case 'Relatório de Clientes':
        return _relatorioClientes();
      case 'Relatório de Veículos':
        return _relatorioVeiculos();
      case 'Relatório de Locações':
        return _relatorioLocacoes(locacaoController.locacoesAtivas, 'Nenhuma locação ativa no momento.');
      case 'Relatório de Devoluções':
        return _relatorioLocacoes(locacaoController.historico, 'Nenhuma locação concluída ainda.');
      case 'Relatório de Desempenho':
        return _relatorioDesempenho();
      default:
        return _vazio('Relatório não encontrado.');
    }
  }

  Widget _vazio(String texto) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(child: Text(texto, style: const TextStyle(color: Colors.grey, fontSize: 15))),
      );

  Widget _relatorioClientes() {
    final lista = clienteController.clientes;
    if (lista.isEmpty) return _vazio('Nenhum cliente cadastrado.');

    return Column(
      children: lista.map((cliente) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: RoyaleColors.azulMarinho,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(cliente.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              'CPF: ${cliente.cpf}  •  CNH: ${cliente.cnh}\nTel: ${cliente.telefone}${cliente.email != null ? '  •  ${cliente.email}' : ''}',
            ),
            isThreeLine: true,
          ),
        );
      }).toList(),
    );
  }

  Widget _relatorioVeiculos() {
    final lista = frotaController.veiculos;
    if (lista.isEmpty) return _vazio('Nenhum veículo cadastrado.');

    return Column(
      children: lista.map((v) {
        final cor = v.status == Veiculo.statusDisponivel
            ? RoyaleColors.statusDisponivel
            : v.status == Veiculo.statusManutencao
                ? RoyaleColors.statusManutencao
                : RoyaleColors.statusAlugado;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: cor, child: const Icon(Icons.directions_car, color: Colors.white)),
            title: Text('${v.marca} ${v.modelo}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Placa: ${v.placa}  •  R\$ ${v.diaria.toStringAsFixed(2)}/dia  •  ${v.quilometragem} km'),
            trailing: Chip(label: Text(v.status), backgroundColor: cor.withValues(alpha: 0.15)),
          ),
        );
      }).toList(),
    );
  }

  Widget _relatorioLocacoes(List locacoes, String mensagemVazia) {
    if (locacoes.isEmpty) return _vazio(mensagemVazia);

    double total = 0;
    for (final l in locacoes) {
      total += l.valorTotal as double;
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: RoyaleColors.azulMarinho, borderRadius: BorderRadius.circular(10)),
          child: Text(
            '${locacoes.length} locação(ões)  •  Total: R\$ ${total.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        ...locacoes.map((l) {
          final cliente = l.nomeCliente ?? 'Cliente #${l.idCliente}';
          final veiculo = l.modeloVeiculo != null ? '${l.modeloVeiculo} (${l.placaVeiculo})' : 'Veículo #${l.idVeiculo}';
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text('$cliente — $veiculo'),
              subtitle: Text(
                '${_formatoData.format(l.dataInicio)} até ${_formatoData.format(l.dataFim)}'
                '${l.kmRodados != null ? '  •  ${l.kmRodados} km rodados' : ''}',
              ),
              trailing: Text('R\$ ${(l.valorTotal as double).toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
        }),
      ],
    );
  }

  Widget _relatorioDesempenho() {
    final total = frotaController.veiculos.length;
    final alugados = frotaController.veiculos.where((v) => v.status == Veiculo.statusAlugado).length;
    final manutencao = frotaController.veiculos.where((v) => v.status == Veiculo.statusManutencao).length;
    final taxaOcupacao = total > 0 ? (alugados / total) * 100 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Eficiência Operacional da Frota',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: RoyaleColors.azulMarinho)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Taxa de utilização da frota', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: taxaOcupacao / 100,
                  backgroundColor: Colors.grey.shade300,
                  color: RoyaleColors.azulMarinho,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 8),
                Text('${taxaOcupacao.toStringAsFixed(1)}% da frota alugada agora ($alugados de $total)'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.build, color: RoyaleColors.statusManutencao),
            title: const Text('Veículos em manutenção'),
            trailing: Text('$manutencao', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.history, color: RoyaleColors.azulMarinho),
            title: const Text('Locações concluídas (histórico)'),
            trailing: Text('${locacaoController.historico.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ),
      ],
    );
  }
}
