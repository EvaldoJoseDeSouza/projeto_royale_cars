import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../models/manutencao.dart';
import '../theme/colors.dart';
import '../utils/validadores.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/checklist_vistoria.dart';
import '../widgets/royale_button.dart';
import '../widgets/royale_footer.dart';

/// Libera o carro da oficina, pela função concluir_manutencao (a mesma da
/// web e do desktop): serviço feito, custo e data. O carro volta a ficar
/// Disponível e o custo entra no Financeiro das 3 plataformas.
class LiberarManutencaoPage extends StatefulWidget {
  final Manutencao manutencao;

  const LiberarManutencaoPage({super.key, required this.manutencao});

  @override
  State<LiberarManutencaoPage> createState() => _LiberarManutencaoPageState();
}

class _LiberarManutencaoPageState extends State<LiberarManutencaoPage> {
  final _formKey = GlobalKey<FormState>();

  static DateTime get _hoje {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
  }

  DateTime _dataLiberacao = _hoje;
  final _servicoController = TextEditingController();
  final _custoController = TextEditingController();
  bool _salvando = false;

  Manutencao get _m => widget.manutencao;

  @override
  void dispose() {
    _servicoController.dispose();
    _custoController.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _dataLiberacao,
      firstDate: _m.dataEntrada,
      lastDate: _hoje,
      helpText: 'Data da liberação',
    );
    if (escolhida != null) setState(() => _dataLiberacao = escolhida);
  }

  Future<void> _liberar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);
    try {
      final custo = lerDinheiro(_custoController.text)!;
      await manutencaoController.liberar(
        manutencaoId: _m.id,
        dataLiberacao: _dataLiberacao,
        servico: _servicoController.text.trim(),
        custo: custo,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: RoyaleColors.statusDisponivel,
          content: Text('O ${_m.nomeVeiculo} foi liberado e está disponível. Custo de ${moeda(custo)} lançado no Financeiro.'),
        ),
      );
      Navigator.pop(context, true);
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: RoyaleColors.statusAlugado,
          content: Text(erro.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AnimatedGoldenTitle('Liberar da oficina', fontSize: 22)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_m.nomeVeiculo} (${_m.placaFormatada})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('Defeito: ${_m.defeito}'),
                      Text('Na oficina desde ${dataBr(_m.dataEntrada)} (${_m.diasParado} dia(s))',
                          style: const TextStyle(color: RoyaleColors.textoMuted)),
                      const SizedBox(height: 6),
                      ChecklistVistoria(manutencao: _m),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _servicoController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Serviço realizado *', prefixIcon: Icon(Icons.handyman)),
                validator: (v) => (v ?? '').trim().length < 5 ? 'Descreva o serviço realizado' : null,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _custoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Custo (R\$) *',
                        hintText: '0,00',
                        helperText: 'Use 0 se foi na garantia',
                      ),
                      validator: (v) {
                        final valor = lerDinheiro(v ?? '');
                        if (valor == null || valor < 0) return 'Informe o custo';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _escolherData,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Liberado em *', prefixIcon: Icon(Icons.event)),
                        child: Text(dataBr(_dataLiberacao), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _salvando
                  ? const Center(child: CircularProgressIndicator(color: RoyaleColors.azulMarinho))
                  : RoyaleButton(label: 'Liberar veículo', onPressed: _liberar, fullWidth: true),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const RoyaleFooter(),
    );
  }
}
