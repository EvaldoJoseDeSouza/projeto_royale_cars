import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../models/veiculo.dart';
import '../theme/colors.dart';
import '../utils/validadores.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_button.dart';
import '../widgets/royale_footer.dart';
import '../widgets/selo_status_veiculo.dart';

/// Cadastro/edição de veículo. Passe [veiculoParaEditar] para abrir em
/// modo edição. Os campos são os mesmos da web e do desktop.
///
/// O STATUS não aparece para escolher: ele muda sozinho com os aluguéis
/// e as manutenções. Na edição, só mostramos qual é.
class CadastroVeiculoPage extends StatefulWidget {
  final Veiculo? veiculoParaEditar;

  const CadastroVeiculoPage({super.key, this.veiculoParaEditar});

  @override
  State<CadastroVeiculoPage> createState() => _CadastroVeiculoPageState();
}

class _CadastroVeiculoPageState extends State<CadastroVeiculoPage> {
  final _formKey = GlobalKey<FormState>();
  Veiculo? get _original => widget.veiculoParaEditar;

  late final _marcaController = TextEditingController(text: _original?.marca);
  late final _modeloController = TextEditingController(text: _original?.modelo);
  late final _anoController = TextEditingController(text: '${_original?.ano ?? ''}');
  late final _placaController = TextEditingController(text: _original?.placaFormatada);
  late final _chassiController = TextEditingController(text: _original?.chassi);
  late final _diariaController = TextEditingController(
    text: _original?.valorDiaria.toStringAsFixed(2).replaceAll('.', ',') ?? '',
  );
  late final _quilometragemController = TextEditingController(text: '${_original?.quilometragem ?? 0}');

  bool _salvando = false;
  bool get _editando => _original != null;

  /// Carro na rua: a quilometragem é atualizada na devolução (regra do banco)
  bool get _kmTravado => _original?.status == Veiculo.statusAlugado;

  /// Ano de fabricação: de 1950 até o ano que vem (modelo do ano seguinte)
  int get _anoMaximo => DateTime.now().year + 1;

  @override
  void dispose() {
    _marcaController.dispose();
    _modeloController.dispose();
    _anoController.dispose();
    _placaController.dispose();
    _chassiController.dispose();
    _diariaController.dispose();
    _quilometragemController.dispose();
    super.dispose();
  }

  Future<void> _salvarVeiculo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);
    try {
      final veiculo = Veiculo(
        id: _original?.id,
        marca: _marcaController.text,
        modelo: _modeloController.text,
        ano: int.parse(_anoController.text),
        placa: _placaController.text,
        chassi: _chassiController.text,
        valorDiaria: lerDinheiro(_diariaController.text)!,
        quilometragem: int.parse(soDigitos(_quilometragemController.text)),
      );

      final mensagem = await frotaController.salvarVeiculo(veiculo);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: RoyaleColors.statusDisponivel, content: Text(mensagem)),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Na edição, mostra o status atual (só para informar)
              if (_editando) ...[
                Row(
                  children: [
                    const Text('Status atual: ', style: TextStyle(color: RoyaleColors.textoMuted)),
                    SeloStatusVeiculo(status: _original!.status),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _marcaController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Marca *', hintText: 'Ex: Ford'),
                      validator: (v) => (v == null || v.trim().length < 2) ? 'Informe a marca' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _modeloController,
                      decoration: const InputDecoration(labelText: 'Modelo *', hintText: 'Ex: Ranger XLT'),
                      validator: (v) => obrigatorio(v, 'O modelo'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _anoController,
                      decoration: const InputDecoration(labelText: 'Ano *', hintText: '2024', counterText: ''),
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      validator: (v) {
                        final ano = int.tryParse(v ?? '');
                        if (ano == null || ano < 1950 || ano > _anoMaximo) return 'Entre 1950 e $_anoMaximo';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _placaController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Placa *', hintText: 'ABC1D23', counterText: ''),
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
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _chassiController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Chassi *',
                  hintText: '17 letras/números',
                  prefixIcon: Icon(Icons.qr_code_2),
                ),
                maxLength: 17,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o chassi';
                  if (limparCodigo(v).length != 17) return 'O chassi tem 17 letras/números';
                  if (!chassiValido(v)) return 'Chassi inválido (não usa as letras I, O e Q)';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _diariaController,
                      decoration: const InputDecoration(labelText: 'Diária (R\$) *', hintText: '350,00'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        final valor = lerDinheiro(v ?? '');
                        if (valor == null || valor <= 0) return 'Valor inválido';
                        if (valor > 100000) return 'Valor alto demais';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _quilometragemController,
                      enabled: !_kmTravado,
                      decoration: InputDecoration(
                        labelText: 'Quilometragem (km) *',
                        helperText: _kmTravado ? 'Atualiza na devolução' : null,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final km = int.tryParse(soDigitos(v ?? ''));
                        if (km == null) return 'Informe a quilometragem';
                        if (km > 2000000) return 'Confira o número';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_editando)
                const Text(
                  'O veículo entra na frota como Disponível. Depois o status muda sozinho com os aluguéis e as manutenções.',
                  style: TextStyle(color: RoyaleColors.textoMuted, fontSize: 12.5),
                ),
              const SizedBox(height: 24),
              _salvando
                  ? const Center(child: CircularProgressIndicator(color: RoyaleColors.azulMarinho))
                  : RoyaleButton(label: 'Salvar Veículo', onPressed: _salvarVeiculo, fullWidth: true),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const RoyaleFooter(),
    );
  }
}
