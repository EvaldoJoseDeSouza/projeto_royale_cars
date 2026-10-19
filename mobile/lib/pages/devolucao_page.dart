import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../models/locacao.dart';
import '../theme/colors.dart';
import '../utils/validadores.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_button.dart';
import '../widgets/royale_footer.dart';

/// Devolução de um aluguel, pela função registrar_devolucao do banco (a
/// mesma da web e do desktop). A conta, igual nas 3 plataformas:
///
///   dias usados × diária combinada  (mínimo 1; devolução adiantada
///                                     cobra só os dias usados)
/// + taxas extras com motivo          (combustível, limpeza, avaria...)
/// = total
///
/// Os dias depois da data prevista aparecem como "atraso" (já estão
/// somados nos dias usados). Se o carro voltou com defeito, ele vai
/// direto para a manutenção em vez de ficar Disponível.
///
/// O valor aqui é uma PRÉVIA; quem calcula de verdade é o banco.
class DevolucaoPage extends StatefulWidget {
  final Locacao locacao;

  const DevolucaoPage({super.key, required this.locacao});

  @override
  State<DevolucaoPage> createState() => _DevolucaoPageState();
}

class _DevolucaoPageState extends State<DevolucaoPage> {
  final _formKey = GlobalKey<FormState>();

  static DateTime get _hoje {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
  }

  late DateTime _dataDevolucao = _hoje;
  late final _kmController = TextEditingController(text: widget.locacao.kmSaida?.toString() ?? '');
  final _taxasController = TextEditingController();
  final _motivoController = TextEditingController();
  final _observacoesController = TextEditingController();
  final _defeitoController = TextEditingController();
  final _oficinaController = TextEditingController();
  bool _comDefeito = false;
  bool _salvando = false;

  Locacao get _l => widget.locacao;

  @override
  void dispose() {
    _kmController.dispose();
    _taxasController.dispose();
    _motivoController.dispose();
    _observacoesController.dispose();
    _defeitoController.dispose();
    _oficinaController.dispose();
    super.dispose();
  }

  // ----- A prévia (a mesma conta do banco) -----
  int get _dias {
    final dias = _dataDevolucao.difference(_l.dataRetirada).inDays;
    return dias < 1 ? 1 : dias;
  }

  int get _diasAtraso {
    final atraso = _dataDevolucao.difference(_l.dataPrevista).inDays;
    return atraso < 0 ? 0 : atraso;
  }

  double get _taxas => lerDinheiro(_taxasController.text) ?? 0;
  double get _valorDiarias => _dias * _l.valorDiaria;
  double get _total => _valorDiarias + _taxas;

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _dataDevolucao,
      firstDate: _l.dataRetirada,
      lastDate: _hoje,
      helpText: 'Data da devolução',
    );
    if (escolhida != null) setState(() => _dataDevolucao = escolhida);
  }

  String? _textoOuNulo(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);
    try {
      final resumo = await locacaoController.devolver(
        locacaoId: _l.id,
        dataDevolucao: _dataDevolucao,
        kmRetorno: int.tryParse(soDigitos(_kmController.text)),
        taxasExtras: _taxas,
        taxasMotivo: _taxas > 0 ? _textoOuNulo(_motivoController) : null,
        observacoes: _textoOuNulo(_observacoesController),
        defeito: _comDefeito ? _textoOuNulo(_defeitoController) : null,
        oficina: _comDefeito ? _textoOuNulo(_oficinaController) : null,
      );
      await frotaController.recarregar();

      if (mounted) await _mostrarResumo(resumo);
      if (mounted) Navigator.pop(context, true); // true = "mudou, atualize a lista"
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: RoyaleColors.statusAlugado,
            content: Text(erro.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// O resumo que o BANCO calculou (é o valor oficial).
  Future<void> _mostrarResumo(Map<String, dynamic> r) {
    final total = (r['valor_total'] as num?)?.toDouble() ?? 0;
    final atraso = (r['dias_atraso'] as num?)?.toInt() ?? 0;
    final kmRodados = r['km_rodados'];
    final statusCarro = '${r['status_veiculo'] ?? ''}';

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Aluguel #${_l.id} encerrado'),
        content: Text(
          '${r['dias']} diária(s)${atraso > 0 ? ' (com $atraso dia(s) de atraso)' : ''}\n'
          '${(r['taxas_extras'] as num? ?? 0) > 0 ? 'Taxas extras: ${moeda((r['taxas_extras'] as num).toDouble())}\n' : ''}'
          'Total: ${moeda(total)}\n'
          '${kmRodados != null ? '$kmRodados km rodados\n' : ''}\n'
          '${statusCarro == 'Em manutenção' ? 'O carro foi para a manutenção.' : 'O carro está disponível para um novo aluguel.'}',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  /// Uma linha da prévia: "rótulo ........ valor"
  Widget _linhaPrevia(String rotulo, String valor, {bool destaque = false}) {
    final estilo = TextStyle(
      color: destaque ? RoyaleColors.dourado : Colors.white,
      fontWeight: destaque ? FontWeight.bold : FontWeight.normal,
      fontSize: destaque ? 22 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(rotulo, style: estilo), Text(valor, style: estilo)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AnimatedGoldenTitle('Devolução', fontSize: 24)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ----- De quem é este aluguel -----
              Card(
                child: ListTile(
                  leading: const Icon(Icons.vpn_key, color: RoyaleColors.azulMarinho),
                  title: Text('#${_l.id} • ${_l.nomeVeiculo} (${_l.placaFormatada})',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${_l.nomeCliente}\n'
                      'Retirada ${dataBr(_l.dataRetirada)} • prevista ${dataBr(_l.dataPrevista)} • '
                      '${moeda(_l.valorDiaria)}/dia'),
                  isThreeLine: true,
                ),
              ),
              const SizedBox(height: 16),

              // ----- Data e km -----
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _escolherData,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Data da devolução *', prefixIcon: Icon(Icons.event)),
                        child: Text(dataBr(_dataDevolucao), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _kmController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Km na devolução *',
                        helperText: _l.kmSaida == null ? null : 'Saiu com ${_l.kmSaida} km',
                      ),
                      validator: (v) {
                        final km = int.tryParse(soDigitos(v ?? ''));
                        if (km == null) return 'Informe o km';
                        if (_l.kmSaida != null && km < _l.kmSaida!) return 'Menor que o de saída';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ----- Taxas extras -----
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _taxasController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Taxas extras (R\$)', hintText: '0,00'),
                      onChanged: (_) => setState(() {}), // atualiza a prévia
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final valor = lerDinheiro(v);
                        if (valor == null || valor < 0) return 'Valor inválido';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _motivoController,
                      decoration: const InputDecoration(labelText: 'Motivo das taxas', hintText: 'Ex.: combustível'),
                      // Com taxa, o motivo é obrigatório (regra do banco)
                      validator: (v) => _taxas > 0 && (v ?? '').trim().length < 3 ? 'Informe o motivo' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _observacoesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Observações (opcional)', prefixIcon: Icon(Icons.notes)),
              ),
              const SizedBox(height: 8),

              // ----- Voltou com defeito? -----
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('O carro voltou com defeito'),
                subtitle: const Text('Ele vai direto para a manutenção em vez de ficar Disponível.'),
                value: _comDefeito,
                onChanged: (v) => setState(() => _comDefeito = v),
              ),
              if (_comDefeito) ...[
                TextFormField(
                  controller: _defeitoController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Qual o defeito? *', prefixIcon: Icon(Icons.build)),
                  validator: (v) => (v ?? '').trim().length < 5 ? 'Descreva o defeito' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _oficinaController,
                  decoration: const InputDecoration(labelText: 'Oficina (opcional)', prefixIcon: Icon(Icons.store)),
                ),
              ],
              const SizedBox(height: 20),

              // ----- Prévia -----
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: RoyaleColors.azulMarinho, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    _linhaPrevia('$_dias diária(s) × ${moeda(_l.valorDiaria)}', moeda(_valorDiarias)),
                    if (_diasAtraso > 0) _linhaPrevia('  (inclui $_diasAtraso dia(s) de atraso)', ''),
                    if (_taxas > 0) _linhaPrevia('Taxas extras', moeda(_taxas)),
                    const Divider(color: Colors.white24),
                    _linhaPrevia('Total', moeda(_total), destaque: true),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _salvando
                  ? const Center(child: CircularProgressIndicator(color: RoyaleColors.azulMarinho))
                  : RoyaleButton(label: 'Confirmar devolução', onPressed: _confirmar, fullWidth: true),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const RoyaleFooter(),
    );
  }
}
