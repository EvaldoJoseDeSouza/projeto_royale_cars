import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../models/cliente.dart';
import '../theme/colors.dart';
import '../utils/validadores.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_button.dart';
import '../widgets/royale_footer.dart';

/// Cadastro/edição de cliente. Passe [clienteParaEditar] para abrir em
/// modo edição (mesmo padrão do modal do desktop).
class CadastroClientePage extends StatefulWidget {
  final Cliente? clienteParaEditar;

  const CadastroClientePage({super.key, this.clienteParaEditar});

  @override
  State<CadastroClientePage> createState() => _CadastroClientePageState();
}

class _CadastroClientePageState extends State<CadastroClientePage> {
  final _formKey = GlobalKey<FormState>();
  late final _nomeController = TextEditingController(text: widget.clienteParaEditar?.nome);
  late final _cpfController = TextEditingController(text: widget.clienteParaEditar?.cpf);
  late final _cnhController = TextEditingController(text: widget.clienteParaEditar?.cnh);
  late final _telefoneController = TextEditingController(text: widget.clienteParaEditar?.telefone);
  late final _emailController = TextEditingController(text: widget.clienteParaEditar?.email);
  late final _enderecoController = TextEditingController(text: widget.clienteParaEditar?.endereco);

  bool _salvando = false;

  bool get _editando => widget.clienteParaEditar != null;

  @override
  void dispose() {
    _nomeController.dispose();
    _cpfController.dispose();
    _cnhController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _enderecoController.dispose();
    super.dispose();
  }

  Future<void> _salvarCliente() async {
    if (!_formKey.currentState!.validate()) return;
    final idEmpresa = authController.idEmpresa;
    if (idEmpresa == null) return;

    setState(() => _salvando = true);
    try {
      final cliente = Cliente(
        id: widget.clienteParaEditar?.id,
        nome: _nomeController.text.trim(),
        cpf: _cpfController.text.trim(),
        cnh: _cnhController.text.trim(),
        telefone: _telefoneController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        endereco: _enderecoController.text.trim().isEmpty ? null : _enderecoController.text.trim(),
      );

      await clienteController.salvarCliente(cliente, idEmpresa);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: RoyaleColors.statusDisponivel,
            content: Text(_editando
                ? 'Cadastro de ${cliente.nome} atualizado com sucesso!'
                : 'Cliente ${cliente.nome} cadastrado com sucesso!'),
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
        title: AnimatedGoldenTitle(_editando ? 'Editar Cliente' : 'Cadastro de Cliente', fontSize: 22),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome completo *', prefixIcon: Icon(Icons.person)),
                validator: (v) => obrigatorio(v, 'O nome'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cpfController,
                      decoration: const InputDecoration(labelText: 'CPF *', prefixIcon: Icon(Icons.badge)),
                      keyboardType: TextInputType.number,
                      maxLength: 14,
                      onChanged: (v) {
                        final novo = mascaraCpf(v);
                        if (novo != v) {
                          _cpfController.value = TextEditingValue(
                            text: novo,
                            selection: TextSelection.collapsed(offset: novo.length),
                          );
                        }
                      },
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe o CPF';
                        if (!cpfValido(v)) return 'CPF inválido';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cnhController,
                      decoration: const InputDecoration(labelText: 'CNH *', prefixIcon: Icon(Icons.credit_card)),
                      keyboardType: TextInputType.number,
                      maxLength: 11,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe a CNH';
                        if (v.replaceAll(RegExp(r'\D'), '').length != 11) return 'CNH deve ter 11 dígitos';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(labelText: 'Telefone *', prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
                maxLength: 15,
                onChanged: (v) {
                  final novo = mascaraTelefone(v);
                  if (novo != v) {
                    _telefoneController.value = TextEditingValue(
                      text: novo,
                      selection: TextSelection.collapsed(offset: novo.length),
                    );
                  }
                },
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o telefone';
                  if (!telefoneValido(v)) return 'Telefone inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'E-mail (opcional)', prefixIcon: Icon(Icons.email_outlined)),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  return emailValido(v) ? null : 'E-mail inválido';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _enderecoController,
                decoration: const InputDecoration(labelText: 'Endereço residencial (opcional)', prefixIcon: Icon(Icons.home_outlined)),
              ),
              const SizedBox(height: 32),
              _salvando
                  ? const CircularProgressIndicator(color: RoyaleColors.azulMarinho)
                  : RoyaleButton(label: 'Salvar Cliente', onPressed: _salvarCliente, fullWidth: true),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const RoyaleFooter(),
    );
  }
}
