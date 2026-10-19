import 'package:flutter/material.dart';
import '../models/painel.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../utils/validadores.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_footer.dart';

/// Financeiro (só para ler, decisão 9 do grupo), com a MESMA conta do
/// desktop e da web:
///   faturamento  = aluguéis finalizados no período
///   manutenção   = custo das manutenções concluídas no período
///   resultado    = faturamento - manutenção
///   a receber    = o previsto dos aluguéis que ainda estão na rua
/// E os últimos 12 meses, da visão vw_faturamento_mensal.
class FinancasPage extends StatefulWidget {
  const FinancasPage({super.key});

  @override
  State<FinancasPage> createState() => _FinancasPageState();
}

class _FinancasPageState extends State<FinancasPage> {
  // Os períodos que dá para escolher: este mês ou o mês passado
  static const _periodos = ['Este mês', 'Mês passado'];
  String _periodo = _periodos.first;
  late Future<ResumoFinanceiro> _resumo = _buscar();

  static const _nomesMes = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

  /// Primeiro e último dia do período escolhido.
  (DateTime, DateTime) get _intervalo {
    final hoje = DateTime.now();
    if (_periodo == 'Este mês') {
      return (DateTime(hoje.year, hoje.month, 1), DateTime(hoje.year, hoje.month, hoje.day));
    }
    // Dia 0 do mês atual = o último dia do mês passado
    return (DateTime(hoje.year, hoje.month - 1, 1), DateTime(hoje.year, hoje.month, 0));
  }

  Future<ResumoFinanceiro> _buscar() {
    final (inicio, fim) = _intervalo;
    return SupabaseService.instance.buscarFinanceiro(inicio, fim);
  }

  Future<void> _recarregar() async {
    final novo = _buscar();
    setState(() => _resumo = novo);
    await novo;
  }

  /// Um cartão com um número grande (ex.: "Faturamento  R$ 12.300,00").
  Widget _indicador(String rotulo, String valor, Color cor, IconData icone) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icone, size: 18, color: cor),
              const SizedBox(width: 6),
              Flexible(child: Text(rotulo, style: const TextStyle(color: RoyaleColors.textoMuted, fontSize: 12.5))),
            ]),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(valor, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cor)),
            ),
          ],
        ),
      ),
    );
  }

  /// Os meses como barras simples: o maior faturamento ocupa a largura toda.
  Widget _meses(List<MesFinanceiro> meses) {
    final ultimos = meses.length > 6 ? meses.sublist(meses.length - 6) : meses;
    // O maior valor (faturamento ou manutenção) vira a barra cheia
    final maior = ultimos.fold<double>(1, (m, x) => [m, x.faturamento, x.manutencao].reduce((a, b) => a > b ? a : b));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Últimos 6 meses (faturamento x manutenção)',
                style: TextStyle(fontWeight: FontWeight.bold, color: RoyaleColors.azulMarinho)),
            const SizedBox(height: 10),
            for (final m in ultimos) ...[
              Row(
                children: [
                  SizedBox(width: 56, child: Text('${_nomesMes[m.mes.month - 1]}/${m.mes.year % 100}')),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: (m.faturamento / maior).clamp(0.0, 1.0),
                          minHeight: 8,
                          color: RoyaleColors.statusDisponivel,
                          backgroundColor: RoyaleColors.fundoApp,
                        ),
                        const SizedBox(height: 2),
                        LinearProgressIndicator(
                          value: (m.manutencao / maior).clamp(0.0, 1.0),
                          minHeight: 5,
                          color: RoyaleColors.statusManutencao,
                          backgroundColor: RoyaleColors.fundoApp,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(moeda(m.resultado), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            const Text('Verde = faturamento • Amarelo = manutenção • À direita: resultado',
                style: TextStyle(color: RoyaleColors.textoMuted, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AnimatedGoldenTitle('Financeiro', fontSize: 24)),
      body: FutureBuilder<ResumoFinanceiro>(
        future: _resumo,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: RoyaleColors.azulMarinho));
          }
          if (snapshot.hasError) {
            return Center(
              child: TextButton(onPressed: _recarregar, child: const Text('Não foi possível carregar. Tocar para tentar de novo.')),
            );
          }

          final r = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _recarregar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                // ----- Escolha do período -----
                Wrap(
                  spacing: 8,
                  children: [
                    for (final p in _periodos)
                      ChoiceChip(
                        label: Text(p),
                        selected: _periodo == p,
                        onSelected: (_) {
                          _periodo = p;
                          _recarregar();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // ----- Os números do período (2 por linha) -----
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.1,
                  children: [
                    _indicador('Faturamento', moeda(r.faturamento), RoyaleColors.statusDisponivel, Icons.trending_up),
                    _indicador('Manutenção', moeda(r.gastoManutencao), RoyaleColors.statusManutencao, Icons.build),
                    _indicador('Resultado', moeda(r.resultado),
                        r.resultado >= 0 ? RoyaleColors.azulMarinho : RoyaleColors.statusAlugado, Icons.account_balance),
                    _indicador('A receber (na rua)', moeda(r.aReceber), RoyaleColors.azulMarinho, Icons.schedule),
                    _indicador('Aluguéis finalizados', '${r.alugueis}', RoyaleColors.azulMarinho, Icons.vpn_key),
                    _indicador('Ticket médio', moeda(r.ticketMedio), RoyaleColors.azulMarinho, Icons.receipt_long),
                  ],
                ),
                const SizedBox(height: 4),
                if (r.meses.isNotEmpty) _meses(r.meses),
                const SizedBox(height: 4),

                // ----- Os aluguéis que entraram no período -----
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                  child: Text('Aluguéis finalizados (${r.entradas.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: RoyaleColors.azulMarinho)),
                ),
                if (r.entradas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum aluguel finalizado neste período.', style: TextStyle(color: Colors.grey)),
                  ),
                for (final e in r.entradas)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: ListTile(
                      dense: true,
                      // Quem só tem a permissão Financeiro não vê clientes: o nome vem vazio
                      title: Text('#${e['id']} • ${(e['clientes'] as Map?)?['nome'] ?? 'Cliente'}'),
                      subtitle: Text(
                        '${(e['veiculos'] as Map?)?['marca'] ?? ''} ${(e['veiculos'] as Map?)?['modelo'] ?? ''}'
                        ' • devolvido em ${dataBr(DateTime.parse('${e['data_devolucao']}'))}',
                      ),
                      trailing: Text(moeda((e['valor_total'] as num).toDouble()),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const RoyaleFooter(),
    );
  }
}
