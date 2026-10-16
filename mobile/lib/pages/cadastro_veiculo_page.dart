import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../models/veiculo.dart';
import '../theme/colors.dart';
import '../utils/validadores.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_button.dart';
import '../widgets/royale_footer.dart';

class CadastroVeiculoPage extends StatefulWidget {
  final Veiculo? veiculoParaEditar;

  const CadastroVeiculoPage({super.key, this.veiculoParaEditar});

  @override
  State<CadastroVeiculoPage> createState() => _CadastroVeiculoPageState();
}

class _CadastroVeiculoPageState extends State<CadastroVeiculoPage> {
  final _formKey = GlobalKey<FormState>();
  late final _modeloController = TextEditingController(text: widget.veiculoParaEditar?.modelo);
  late final _marcaController = TextEditingController(text: widget.veiculoParaEditar?.marca);
  late final _placaController = TextEditingController(text: widget.veiculoParaEditar?.placa);
  late final _diariaController =
      TextEditingController(text: widget.veiculoParaEditar?.diaria.toStringAsFixed(2));
  late final _quilometragemController =
      TextEditingController(text: '${widget.veiculoParaEditar?.quilometragem ?? 0}');
  late String _status = widget.veiculoParaEditar?.status ?? Veiculo.statusDisponivel;

  bool _salvando = false;
  bool get _editando => widget.veiculoParaEditar != null;

  @override
  void dispose() {
    _modeloController.dispose();
    _marcaController.dispose();
    _placaController.dispose();
    _diariaController.dispose();
    _quilometragemController.dispose();
    super.dispose();
  }

  Future<void> _salvarVeiculo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);
    try {
      final valorDiaria = double.tryParse(_diariaController.text.replaceAll(',', '.')) ?? 0;
      final veiculo = Veiculo(
        id: widget.veiculoParaEditar?.id,
        modelo: _modeloController.text.trim(),
        marca: _marcaController.text.trim(),
        placa: _placaController.text.trim().toUpperCase(),
        diaria: valorDiaria,
        status: _status,
        quilometragem: int.tryParse(_quilometragemController.text) ?? 0,
      );

      await frotaController.salvarVeiculo(veiculo);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: RoyaleColors.statusDisponivel,
            content: Text(_editando
                ? 'Veículo ${veiculo.modelo} atualizado com sucesso!'
                : 'Veículo ${veiculo.modelo} cadastrado com sucesso!'),
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
      appBar: AppBar(
        title: AnimatedGoldenTitle(_editando ? 'Editar Veículo' : 'Cadastro de Veículo', fontSize: 22),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _modeloController,
                decoration: const InputDecoration(labelText: 'Modelo *', hintText: 'Ex: Mustang GT'),
                validator: (v) => obrigatorio(v, 'O modelo'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _marcaController,
                decoration: const InputDecoration(labelText: 'Marca / Fabricante *', hintText: 'Ex: Ford'),
                validator: (v) => obrigatorio(v, 'A marca'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _placaController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Placa *', hintText: 'ABC1D23'),
                      maxLength: 8,
                      onChanged: (v) {
                        final novo = mascaraPlaca(v);
                        if (novo != v) {
                          _placaController.value = TextEditingValue(
                            text: novo,
                            selection: TextSelection.collapsed(offset: novo.length),
                          );
                        }
                      },
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe a placa';
                        if (!placaValida(v)) return 'Placa inválida';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _diariaController,
                      decoration: const InputDecoration(labelText: 'Diária (R\$) *', hintText: '350.00'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe a diária';
                        final valor = double.tryParse(v.replaceAll(',', '.'));
                        if (valor == null || valor <= 0) return 'Valor inválido';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 🌟 Quilometragem — pedido da banca (acompanhamento de km)
              TextFormField(
                controller: _quilometragemController,
                decoration: const InputDecoration(
                  labelText: 'Quilometragem atual (km) *',
                  prefixIcon: Icon(Icons.speed),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe a quilometragem';
                  if (int.tryParse(v) == null) return 'Informe apenas números';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status *'),
                items: const [
                  DropdownMenuItem(value: Veiculo.statusDisponivel, child: Text('Disponível')),
                  DropdownMenuItem(value: Veiculo.statusAlugado, child: Text('Alugado')),
                  DropdownMenuItem(value: Veiculo.statusManutencao, child: Text('Em Manutenção')),
                ],
                onChanged: (v) => setState(() => _status = v ?? Veiculo.statusDisponivel),
              ),
              const SizedBox(height: 32),
              _salvando
                  ? const CircularProgressIndicator(color: RoyaleColors.azulMarinho)
                  : RoyaleButton(label: 'Salvar Veículo', onPressed: _salvarVeiculo, fullWidth: true),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const RoyaleFooter(),
    );
  }
}
