import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../models/manutencao.dart';
import '../theme/colors.dart';
import '../utils/validadores.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_button.dart';
import '../widgets/royale_footer.dart';

/// Envia um carro DISPONÍVEL para a oficina, pela função abrir_manutencao
/// (a mesma da web e do desktop). A vistoria (checklist) é opcional.
///
/// Carro que volta de aluguel com defeito não passa por aqui: ele vai
/// para a oficina direto na devolução.
class EnviarManutencaoPage extends StatefulWidget {
  const EnviarManutencaoPage({super.key});

  @override
  State<EnviarManutencaoPage> createState() => _EnviarManutencaoPageState();
}

class _EnviarManutencaoPageState extends State<EnviarManutencaoPage> {
  final _formKey = GlobalKey<FormState>();

  static DateTime get _hoje {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
  }

  int? _veiculoId;
  final _defeitoController = TextEditingController();
  final _oficinaController = TextEditingController();
  DateTime _dataEntrada = _hoje;
  DateTime? _previsao;

  // Vistoria: desligada = itens "não conferidos" (null) no banco
  bool _fazerVistoria = false;
  final List<bool> _itens = [true, true, true, true]; // motor, freios, pneus, óleo

  bool _salvando = false;

  @override
  void dispose() {
    _defeitoController.dispose();
    _oficinaController.dispose();
    super.dispose();
  }

  Future<void> _escolherEntrada() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _dataEntrada,
      firstDate: _hoje.subtract(const Duration(days: 30)),
      lastDate: _hoje,
      helpText: 'Entrada na oficina',
    );
    if (escolhida == null) return;
    setState(() {
      _dataEntrada = escolhida;
      if (_previsao != null && _previsao!.isBefore(escolhida)) _previsao = null;
    });
  }

  Future<void> _escolherPrevisao() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _previsao ?? _dataEntrada.add(const Duration(days: 3)),
      firstDate: _dataEntrada,
      lastDate: _dataEntrada.add(const Duration(days: 365)),
      helpText: 'Previsão de liberação',
    );
    if (escolhida != null) setState(() => _previsao = escolhida);
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);
    try {
      await manutencaoController.enviarParaOficina(
        veiculoId: _veiculoId!,
        defeito: _defeitoController.text.trim(),
        oficina: _oficinaController.text.trim().isEmpty ? null : _oficinaController.text.trim(),
        dataEntrada: _dataEntrada,
        previsao: _previsao,
        // Sem vistoria, os 4 itens vão como "não conferido" (null)
        checklist: _fazerVistoria ? List<bool?>.from(_itens) : const [null, null, null, null],
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: RoyaleColors.statusDisponivel,
          content: Text('Carro enviado para a oficina. Ele fica bloqueado para aluguel até ser liberado.'),
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

  Widget _campoData(String rotulo, String texto, VoidCallback aoTocar) {
    return InkWell(
      onTap: aoTocar,
      child: InputDecorator(
        decoration: InputDecoration(labelText: rotulo, prefixIcon: const Icon(Icons.event)),
        child: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: frotaController,
      builder: (context, child) {
        // Só carro Disponível vai para a oficina por aqui (regra do banco)
        final disponiveis = frotaController.veiculosDisponiveis;

        return Scaffold(
          appBar: AppBar(title: const AnimatedGoldenTitle('Enviar para oficina', fontSize: 22)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (disponiveis.isEmpty)
                    const Text('Nenhum carro disponível. Carro alugado vai para a oficina na devolução.',
                        style: TextStyle(color: RoyaleColors.statusAlugado))
                  else
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _veiculoId,
                      decoration: const InputDecoration(labelText: 'Veículo *', prefixIcon: Icon(Icons.directions_car)),
                      items: disponiveis
                          .map((v) => DropdownMenuItem(
                                value: v.id,
                                child: Text('${v.nomeCompleto} (${v.placaFormatada})', overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (id) => setState(() => _veiculoId = id),
                      validator: (id) => id == null ? 'Selecione o veículo' : null,
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _defeitoController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Defeito / motivo *', prefixIcon: Icon(Icons.report_problem)),
                    validator: (v) => (v ?? '').trim().length < 5 ? 'Descreva o defeito' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _oficinaController,
                    decoration: const InputDecoration(labelText: 'Oficina (opcional)', prefixIcon: Icon(Icons.store)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _campoData('Entrada *', dataBr(_dataEntrada), _escolherEntrada)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _campoData('Previsão (opcional)', _previsao == null ? '-' : dataBr(_previsao!), _escolherPrevisao),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ----- Vistoria (o antigo "laudo" do celular) -----
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fazer a vistoria agora'),
                    subtitle: const Text('Desmarque o que estiver com problema.'),
                    value: _fazerVistoria,
                    onChanged: (v) => setState(() => _fazerVistoria = v),
                  ),
                  if (_fazerVistoria)
                    for (var i = 0; i < _itens.length; i++)
                      CheckboxListTile(
                        dense: true,
                        title: Text('${Manutencao.itensChecklist[i]} OK'),
                        value: _itens[i],
                        activeColor: RoyaleColors.azulMarinho,
                        onChanged: (v) => setState(() => _itens[i] = v ?? false),
                      ),
                  const SizedBox(height: 24),
                  _salvando
                      ? const Center(child: CircularProgressIndicator(color: RoyaleColors.azulMarinho))
                      : RoyaleButton(
                          label: 'Enviar para oficina',
                          onPressed: disponiveis.isEmpty ? null : _enviar,
                          fullWidth: true,
                        ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: const RoyaleFooter(),
        );
      },
    );
  }
}
