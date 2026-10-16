import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../models/veiculo.dart';
import '../models/laudo_manutencao.dart';
import '../theme/colors.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_footer.dart';
import '../widgets/royale_button.dart';

class ManutencaoPage extends StatefulWidget {
  const ManutencaoPage({super.key});

  @override
  State<ManutencaoPage> createState() => _ManutencaoPageState();
}

class _ManutencaoPageState extends State<ManutencaoPage> {
  Veiculo? _veiculoSelecionado;
  bool _motorOk = true;
  bool _freiosOk = true;
  bool _pneusOk = true;
  bool _oleoOk = true;
  final _obsController = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _salvarLaudo() async {
    if (_veiculoSelecionado == null) return;

    setState(() => _salvando = true);
    try {
      final novoLaudo = LaudoManutencao(
        idVeiculo: _veiculoSelecionado!.id!,
        placa: _veiculoSelecionado!.placa,
        motorOk: _motorOk,
        freiosOk: _freiosOk,
        pneusOk: _pneusOk,
        oleoOk: _oleoOk,
        observacoes: _obsController.text,
        dataRegistro: DateTime.now(),
      );

      await manutencaoController.salvarLaudo(novoLaudo);
      await frotaController.recarregar();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: RoyaleColors.statusDisponivel,
            content: Text("Laudo da placa ${novoLaudo.placa} salvo! Veículo marcado como Em Manutenção."),
          ),
        );
        setState(() {
          _veiculoSelecionado = null;
          _motorOk = true;
          _freiosOk = true;
          _pneusOk = true;
          _oleoOk = true;
          _obsController.clear();
        });
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
    return ListenableBuilder(
      listenable: frotaController,
      builder: (context, child) {
        final todosVeiculos = frotaController.veiculos;

        return Scaffold(
          appBar: AppBar(title: const AnimatedGoldenTitle("Manutenção", fontSize: 24)),
          body: todosVeiculos.isEmpty
              ? const Center(
                  child: Text("Nenhum veículo cadastrado na frota para inspeção.",
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Ficha de Inspeção Técnica",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: RoyaleColors.azulMarinho)),
                      const SizedBox(height: 5),
                      const Text("Selecione um veículo para preencher o checklist. Ao salvar, ele é marcado como \"Em Manutenção\" na frota.",
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<Veiculo>(
                        initialValue: _veiculoSelecionado,
                        decoration: const InputDecoration(labelText: "Selecione o Veículo", prefixIcon: Icon(Icons.build_rounded)),
                        items: todosVeiculos
                            .map((v) => DropdownMenuItem(value: v, child: Text("${v.marca} ${v.modelo} (${v.placa})")))
                            .toList(),
                        onChanged: (v) => setState(() => _veiculoSelecionado = v),
                      ),
                      const SizedBox(height: 20),
                      if (_veiculoSelecionado != null) ...[
                        const Divider(),
                        CheckboxListTile(
                          title: const Text("Motor em ordem"),
                          value: _motorOk,
                          activeColor: RoyaleColors.azulMarinho,
                          onChanged: (v) => setState(() => _motorOk = v!),
                        ),
                        CheckboxListTile(
                          title: const Text("Freios revisados"),
                          value: _freiosOk,
                          activeColor: RoyaleColors.azulMarinho,
                          onChanged: (v) => setState(() => _freiosOk = v!),
                        ),
                        CheckboxListTile(
                          title: const Text("Pneus e calibragem OK"),
                          value: _pneusOk,
                          activeColor: RoyaleColors.azulMarinho,
                          onChanged: (v) => setState(() => _pneusOk = v!),
                        ),
                        CheckboxListTile(
                          title: const Text("Óleo e fluidos OK"),
                          value: _oleoOk,
                          activeColor: RoyaleColors.azulMarinho,
                          onChanged: (v) => setState(() => _oleoOk = v!),
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: _obsController,
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: "Observações do técnico"),
                        ),
                        const SizedBox(height: 25),
                        _salvando
                            ? const Center(child: CircularProgressIndicator(color: RoyaleColors.azulMarinho))
                            : RoyaleButton(label: "Salvar Laudo Técnico", onPressed: _salvarLaudo),
                      ],
                    ],
                  ),
                ),
          bottomNavigationBar: const RoyaleFooter(),
        );
      },
    );
  }
}
