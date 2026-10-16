import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_footer.dart';

/// Painel financeiro — usa o MESMO cálculo do app desktop
/// (faturamento do mês atual x anterior, ticket médio, recebimento
/// projetado das locações ativas), buscado direto do Supabase.
class FinancasPage extends StatefulWidget {
  const FinancasPage({super.key});

  @override
  State<FinancasPage> createState() => _FinancasPageState();
}

class _FinancasPageState extends State<FinancasPage> {
  Map<String, dynamic>? _dados;
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final dados = await SupabaseService.instance.buscarDadosFinanceiros();
      setState(() => _dados = dados);
    } catch (erro) {
      setState(() => _erro = erro.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AnimatedGoldenTitle('Finanças', fontSize: 24),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _carregar)],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: RoyaleColors.azulMarinho))
          : _erro != null
              ? Center(child: Text(_erro!, style: const TextStyle(color: RoyaleColors.statusAlugado)))
              : _conteudo(),
      bottomNavigationBar: const RoyaleFooter(),
    );
  }

  Widget _conteudo() {
    final dados = _dados!;
    final faturamento = dados['faturamentoTotal'] as double;
    final projetado = dados['recebimentoProjetado'] as double;
    final ticketMedio = dados['ticketMedio'] as double;
    final variacao = dados['variacaoPercentual'] as double;
    final fluxo = (dados['fluxoCaixa'] as List).cast<Map<String, dynamic>>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Faturamento do mês', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: RoyaleColors.azulMarinho)),
          const SizedBox(height: 12),
          _cardDestaque(
            'R\$ ${faturamento.toStringAsFixed(2)}',
            variacao >= 0
                ? '▲ ${variacao.toStringAsFixed(1)}% em relação ao mês anterior'
                : '▼ ${variacao.abs().toStringAsFixed(1)}% em relação ao mês anterior',
            variacao >= 0,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _cardMetrica('Recebimento projetado', 'R\$ ${projetado.toStringAsFixed(2)}', Icons.trending_up, Colors.teal)),
              const SizedBox(width: 12),
              Expanded(child: _cardMetrica('Ticket médio', 'R\$ ${ticketMedio.toStringAsFixed(2)}', Icons.receipt_long, Colors.indigo)),
            ],
          ),
          const SizedBox(height: 28),
          const Text('Locações concluídas recentemente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: RoyaleColors.azulMarinho)),
          const SizedBox(height: 8),
          if (fluxo.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Nenhuma locação concluída ainda.', style: TextStyle(color: Colors.grey)),
            )
          else
            ...fluxo.take(10).map((loc) {
              final cliente = loc['clientes'] is Map ? loc['clientes']['nome'] : 'Cliente';
              final veiculo = loc['veiculos'] is Map ? '${loc['veiculos']['modelo']} (${loc['veiculos']['placa']})' : 'Veículo';
              final valor = (loc['valor_total'] is num) ? (loc['valor_total'] as num).toDouble() : 0.0;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: RoyaleColors.statusDisponivel),
                  title: Text('$cliente — $veiculo'),
                  trailing: Text('R\$ ${valor.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _cardDestaque(String valor, String legenda, bool positivo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: RoyaleColors.azulMarinho, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(valor, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: RoyaleColors.dourado)),
          const SizedBox(height: 4),
          Text(legenda, style: TextStyle(color: positivo ? Colors.greenAccent.shade100 : Colors.redAccent.shade100, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _cardMetrica(String label, String valor, IconData icon, Color cor) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cor, size: 26),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(valor, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
