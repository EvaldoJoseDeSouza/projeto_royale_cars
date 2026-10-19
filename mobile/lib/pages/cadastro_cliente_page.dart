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
///
/// Os campos são os mesmos da web e do desktop: nome completo, CPF, CNH
/// com a validade, telefone, e-mail (obrigatório) e endereço (opcional).
class CadastroClientePage extends StatefulWidget {
  final Cliente? clienteParaEditar;

  const CadastroClientePage({super.key, this.clienteParaEditar});

  @override
  State<CadastroClientePage> createState() => _CadastroClientePageState();
}

class _CadastroClientePageState extends State<CadastroClientePage> {
  final _formKey = GlobalKey<FormState>();

  // Na edição, os campos já abrem preenchidos (com máscara, para ler fácil)
  late final _nomeController = TextEditingController(text: widget.clienteParaEditar?.nome);
  late final _cpfController = TextEditingController(text: widget.clienteParaEditar?.cpfFormatado);
  late final _cnhController = TextEditingController(text: widget.clienteParaEditar?.cnh);
  late final _telefoneController = TextEditingController(text: widget.clienteParaEditar?.telefoneFormatado);
  late final _emailController = TextEditingController(text: widget.clienteParaEditar?.email);
  late final _enderecoController = TextEditingController(text: widget.clienteParaEditar?.endereco);

  // A validade da CNH é escolhida num calendário (não se digita)
  late DateTime? _cnhValidade = widget.clienteParaEditar?.cnhValidade;
  late final _validadeController = TextEditingController(
    text: _cnhValidade == null ? '' : dataBr(_cnhValidade!),
  );

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
    _validadeController.dispose();
    super.dispose();
  }

  /// Abre o calendário para escolher a validade da CNH.
  /// Mesmos limites do desktop: de 10 anos atrás até 15 anos para frente.
  Future<void> _escolherValidade() async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _cnhValidade ?? hoje,
      firstDate: DateTime(hoje.year - 10, hoje.month, hoje.day),
      lastDate: DateTime(hoje.year + 15, hoje.month, hoje.day),
      helpText: 'Validade da CNH',
    );

    if (escolhida != null) {
      setState(() {
        _cnhValidade = escolhida;
        _validadeController.text = dataBr(escolhida);
      });
    }
  }

  /// Aplica a máscara enquanto a pessoa digita, sem pular o cursor.
  void _aplicarMascara(TextEditingController controller, String Function(String) mascara, String valor) {
    final novo = mascara(valor);
    if (novo != valor) {
      controller.value = TextEditingValue(
        text: novo,
        selection: TextSelection.collapsed(offset: novo.length),
      );
    }
  }

  Future<void> _salvarCliente() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);
    try {
      final cliente = Cliente(
        id: widget.clienteParaEditar?.id,
        nome: _nomeController.text,
        cpf: _cpfController.text,
        cnh: _cnhController.text,
        cnhValidade: _cnhValidade!,
        email: _emailController.text,
        telefone: _telefoneController.text,
        endereco: _enderecoController.text,
      );

      final mensagem = await clienteController.salvarCliente(cliente);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // Laranja quando há aviso da CNH; verde quando está tudo certo
            backgroundColor: mensagem.contains('Atenção') ? RoyaleColors.statusManutencao : RoyaleColors.statusDisponivel,
            content: Text(mensagem),
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
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome completo *', prefixIcon: Icon(Icons.person)),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o nome';
                  if (!nomeCompletoValido(v)) return 'Informe nome e sobrenome';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cpfController,
                decoration: const InputDecoration(labelText: 'CPF *', prefixIcon: Icon(Icons.badge), counterText: ''),
                keyboardType: TextInputType.number,
                maxLength: 14,
                onChanged: (v) => _aplicarMascara(_cpfController, mascaraCpf, v),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o CPF';
                  if (!cpfValido(v)) return 'CPF inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cnhController,
                      decoration: const InputDecoration(labelText: 'CNH *', prefixIcon: Icon(Icons.credit_card), counterText: ''),
                      keyboardType: TextInputType.number,
                      maxLength: 11,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe a CNH';
                        if (soDigitos(v).length != 11) return 'A CNH tem 11 números';
                        if (!cnhValida(v)) return 'CNH inválida';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _validadeController,
                      readOnly: true, // não se digita: toca e abre o calendário
                      onTap: _escolherValidade,
                      decoration: const InputDecoration(labelText: 'Validade *', prefixIcon: Icon(Icons.event)),
                      validator: (_) => _cnhValidade == null ? 'Informe a validade' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(labelText: 'Telefone *', prefixIcon: Icon(Icons.phone), counterText: ''),
                keyboardType: TextInputType.phone,
                maxLength: 15,
                onChanged: (v) => _aplicarMascara(_telefoneController, mascaraTelefone, v),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o telefone';
                  if (!telefoneValido(v)) return 'Telefone inválido. Ex.: (19) 99999-9999';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'E-mail *', prefixIcon: Icon(Icons.email_outlined)),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                  return emailValido(v) ? null : 'E-mail inválido';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _enderecoController,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Endereço (opcional)', prefixIcon: Icon(Icons.home_outlined)),
              ),
              const SizedBox(height: 24),
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
