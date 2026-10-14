import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../models/locacao.dart';
import '../theme/colors.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/assinatura_digital.dart';
import '../widgets/royale_button.dart';
import '../widgets/royale_footer.dart';

class LocacaoPage extends StatefulWidget {
  const LocacaoPage({super.key});

  @override
  State<LocacaoPage> createState() => _LocacaoPageState();
}

class _LocacaoPageState extends State<LocacaoPage> {
  final _formKey = GlobalKey<FormState>();

  int? _clienteSelecionadoId;
  int? _veiculoSelecionadoId;
  DateTime _dataRetirada = DateTime.now();
  DateTime _dataDevolucao = DateTime.now().add(const Duration(days: 1));
  double _valorTotalEstimado = 0.0;
  final _kmSaidaController = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _kmSaidaController.dispose();
    super.dispose();
  }

  void _calcularOrcamento() {
    if (_veiculoSelecionadoId == null) return;
    try {
      final veiculo = frotaController.veiculos.firstWhere((v) => v.id == _veiculoSelecionadoId);
      int dias = _dataDevolucao.difference(_dataRetirada).inDays;
      if (dias <= 0) dias = 1;
      setState(() {
        _valorTotalEstimado = dias * veiculo.diaria;
        if (_kmSaidaController.text.isEmpty) {
          _kmSaidaController.text = '${veiculo.quilometragem}';
        }
      });
    } catch (_) {
      // veículo não encontrado — ignora
    }
  }

  Future<void> _registrarLocacao() async {
    if (!_formKey.currentState!.validate() || _clienteSelecionadoId == null || _veiculoSelecionadoId == null) {
      return;
    }
    final idEmpresa = authController.idEmpresa;
    if (idEmpresa == null) return;

    final cliente = clienteController.clientes.firstWhere((c) => c.id == _clienteSelecionadoId);
    final veiculo = frotaController.veiculos.firstWhere((v) => v.id == _veiculoSelecionadoId);

    // 🌟 Captura da assinatura digital do cliente ANTES de confirmar —
    // é o contrato de locação sendo assinado na hora.
    final assinaturaBase64 = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => TelaAssinaturaDigital(
          tituloContrato: 'Assinatura do contrato — ${cliente.nome}',
        ),
      ),
    );

    if (assinaturaBase64 == null) return; // cliente cancelou a assinatura

    setState(() => _salvando = true);
    try {
      final novaLocacao = Locacao(
        idCliente: _clienteSelecionadoId!,
        idVeiculo: _veiculoSelecionadoId!,
        dataInicio: _dataRetirada,
        dataFim: _dataDevolucao,
        valorTotal: _valorTotalEstimado,
        status: Locacao.statusAtivo,
        kmSaida: int.tryParse(_kmSaidaController.text) ?? veiculo.quilometragem,
        assinaturaBase64: assinaturaBase64,
      );

      await locacaoController.registrarLocacao(novaLocacao, idEmpresa);
      await frotaController.recarregar(idEmpresa);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: RoyaleColors.statusDisponivel,
            content: Text('Locação registrada e contrato assinado com sucesso!'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AnimatedGoldenTitle("Nova Locação", fontSize: 24)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Cliente", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListenableBuilder(
                  listenable: clienteController,
                  builder: (context, child) {
                    if (clienteController.clientes.isEmpty) {
                      return const Text('Cadastre um cliente antes de registrar uma locação.',
                          style: TextStyle(color: RoyaleColors.statusAlugado));
                    }
                    return DropdownButtonFormField<int>(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.person)),
                      hint: const Text("Escolha um cliente"),
                      initialValue: _clienteSelecionadoId,
                      items: clienteController.clientes
                          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nome)))
                          .toList(),
                      onChanged: (val) => setState(() => _clienteSelecionadoId = val),
                      validator: (val) => val == null ? "Selecione um cliente" : null,
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Text("Veículo Disponível", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ListenableBuilder(
                  listenable: frotaController,
                  builder: (context, child) {
                    final disponiveis = frotaController.veiculosDisponiveis;
                    if (disponiveis.isEmpty) {
                      return const Text('Nenhum veículo disponível no momento.',
                          style: TextStyle(color: RoyaleColors.statusAlugado));
                    }
                    return DropdownButtonFormField<int>(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.directions_car)),
                      hint: const Text("Escolha um carro"),
                      initialValue: _veiculoSelecionadoId,
                      items: disponiveis
                          .map((v) => DropdownMenuItem(value: v.id, child: Text("${v.marca} ${v.modelo} (${v.placa})")))
                          .toList(),
                      onChanged: (val) {
                        setState(() => _veiculoSelecionadoId = val);
                        _calcularOrcamento();
                      },
                      validator: (val) => val == null ? "Selecione um veículo" : null,
                    );
                  },
                ),
                const SizedBox(height: 20),
                // 🌟 Quilometragem de saída — pedido da banca
                TextFormField(
                  controller: _kmSaidaController,
                  decoration: const InputDecoration(
                    labelText: 'Quilometragem na retirada (km) *',
                    prefixIcon: Icon(Icons.speed),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Informe a quilometragem de saída';
                    if (int.tryParse(v) == null) return 'Informe apenas números';
                    return null;
                  },
                ),
                const SizedBox(height: 25),
                const Text("Período da Locação", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final pickedRange = await showDateRangePicker(
                      context: context,
                      initialDateRange: DateTimeRange(start: _dataRetirada, end: _dataDevolucao),
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime(DateTime.now().year + 2),
                    );
                    if (pickedRange != null) {
                      setState(() {
                        _dataRetirada = pickedRange.start;
                        _dataDevolucao = pickedRange.end;
                      });
                      _calcularOrcamento();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.date_range, color: RoyaleColors.azulMarinho),
                        Text(
                          "${_dataRetirada.day}/${_dataRetirada.month} até ${_dataDevolucao.day}/${_dataDevolucao.month}/${_dataDevolucao.year}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
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
                      const Text("VALOR TOTAL ESTIMADO",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                      const SizedBox(height: 5),
                      Text(
                        "R\$ ${_valorTotalEstimado.toStringAsFixed(2)}",
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: RoyaleColors.dourado),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                _salvando
                    ? const Center(child: CircularProgressIndicator(color: RoyaleColors.azulMarinho))
                    : RoyaleButton(label: "Assinar contrato e confirmar", onPressed: _registrarLocacao),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const RoyaleFooter(),
    );
  }
}
