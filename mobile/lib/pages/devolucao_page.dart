import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../models/locacao.dart';
import '../models/veiculo.dart';
import '../theme/colors.dart';
import '../utils/contrato_pdf.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_button.dart';
import '../widgets/royale_footer.dart';

class DevolucaoPage extends StatefulWidget {
  const DevolucaoPage({super.key});

  @override
  State<DevolucaoPage> createState() => _DevolucaoPageState();
}

class _DevolucaoPageState extends State<DevolucaoPage> {
  final _formKey = GlobalKey<FormState>();

  int? _veiculoSelecionadoId;
  Locacao? _locacaoAtiva;
  final _kmRetornoController = TextEditingController();
  final _multasController = TextEditingController(text: '0');
  bool _salvando = false;

  double get _valorBaseContrato => _locacaoAtiva?.valorTotal ?? 0;
  double get _valorTotalFechamento {
    final multa = double.tryParse(_multasController.text.replaceAll(',', '.')) ?? 0;
    return _valorBaseContrato + multa;
  }

  @override
  void dispose() {
    _kmRetornoController.dispose();
    _multasController.dispose();
    super.dispose();
  }

  void _selecionarVeiculo(int? idVeiculo) {
    if (idVeiculo == null) return;
    final locacao = locacaoController.locacoesAtivas
        .where((l) => l.idVeiculo == idVeiculo)
        .cast<Locacao?>()
        .firstWhere((_) => true, orElse: () => null);

    setState(() {
      _veiculoSelecionadoId = idVeiculo;
      _locacaoAtiva = locacao;
      final veiculo = frotaController.veiculos.firstWhere((v) => v.id == idVeiculo);
      _kmRetornoController.text = '${locacao?.kmSaida ?? veiculo.quilometragem}';
    });
  }

  Future<void> _concluirDevolucao() async {
    if (!_formKey.currentState!.validate() || _veiculoSelecionadoId == null || _locacaoAtiva == null) {
      return;
    }
    final idEmpresa = authController.idEmpresa;
    if (idEmpresa == null) return;

    setState(() => _salvando = true);
    try {
      final kmRetorno = int.tryParse(_kmRetornoController.text);
      await locacaoController.finalizarLocacao(
        idLocacao: _locacaoAtiva!.id!,
        idVeiculo: _veiculoSelecionadoId!,
        idEmpresa: idEmpresa,
        kmRetorno: kmRetorno,
        novoValorTotal: _valorTotalFechamento,
      );
      await frotaController.recarregar(idEmpresa);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: RoyaleColors.statusDisponivel,
            content: Text('Devolução realizada! Veículo liberado para nova locação.'),
          ),
        );
        Navigator.pop(context);
      }
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

  Future<void> _gerarContrato() async {
    if (_locacaoAtiva == null || _veiculoSelecionadoId == null) return;
    try {
      final cliente = clienteController.clientes.firstWhere((c) => c.id == _locacaoAtiva!.idCliente);
      final veiculo = frotaController.veiculos.firstWhere((v) => v.id == _veiculoSelecionadoId);
      await ContratoPdf.gerarEAbrir(locacao: _locacaoAtiva!, cliente: cliente, veiculo: veiculo);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: RoyaleColors.statusAlugado,
            content: Text('Não foi possível gerar o contrato — cliente não encontrado.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final carrosAlugados = frotaController.veiculos.where((v) => v.status == Veiculo.statusAlugado).toList();

    return Scaffold(
      appBar: AppBar(title: const AnimatedGoldenTitle("Devolução", fontSize: 24)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Selecione o Veículo a ser Devolvido", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              carrosAlugados.isEmpty
                  ? const Text('Nenhum veículo alugado no momento.', style: TextStyle(color: RoyaleColors.textoMuted))
                  : DropdownButtonFormField<int>(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.directions_car)),
                      hint: const Text("Escolha um carro alugado"),
                      initialValue: _veiculoSelecionadoId,
                      items: carrosAlugados
                          .map((v) => DropdownMenuItem(value: v.id, child: Text("${v.marca} ${v.modelo} (${v.placa})")))
                          .toList(),
                      onChanged: _selecionarVeiculo,
                      validator: (val) => val == null ? "Selecione o veículo" : null,
                    ),
              if (_veiculoSelecionadoId != null) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _kmRetornoController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'KM na devolução *', prefixIcon: Icon(Icons.speed)),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Insira a KM';
                          final km = int.tryParse(v);
                          if (km == null) return 'Apenas números';
                          if (_locacaoAtiva?.kmSaida != null && km < _locacaoAtiva!.kmSaida!) {
                            return 'Não pode ser menor que a KM de saída';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: TextFormField(
                        controller: _multasController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Taxas/Multas (R\$)'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: RoyaleColors.azulMarinho,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text("Valor base do contrato: R\$ ${_valorBaseContrato.toStringAsFixed(2)}",
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 8),
                      const Text("TOTAL A PAGAR",
                          style: TextStyle(letterSpacing: 1.2, fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text(
                        "R\$ ${_valorTotalFechamento.toStringAsFixed(2)}",
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: RoyaleColors.dourado),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _gerarContrato,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Ver / imprimir contrato assinado'),
                ),
                const SizedBox(height: 20),
                _salvando
                    ? const Center(child: CircularProgressIndicator(color: RoyaleColors.azulMarinho))
                    : RoyaleButton(label: "Concluir Devolução", onPressed: _concluirDevolucao),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: const RoyaleFooter(),
    );
  }
}
