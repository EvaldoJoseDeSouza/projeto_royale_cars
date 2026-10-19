import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../models/cliente.dart';
import '../models/locacao.dart';
import '../models/veiculo.dart';
import '../theme/colors.dart';
import '../utils/contrato_pdf.dart';
import '../utils/validadores.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/assinatura_digital.dart';
import '../widgets/royale_button.dart';
import '../widgets/royale_footer.dart';

/// Nova locação (retirada do carro), no MESMO roteiro da web e do desktop:
///
///  1. Escolhe cliente, carro, datas e confere a quilometragem de saída.
///  2. O cliente assina o contrato na tela do celular.
///  3. A assinatura vai para o bucket "contratos" e o banco registra o
///     aluguel pela função registrar_aluguel, que confere tudo de novo,
///     calcula o valor e marca o carro como Alugado.
///
/// O valor que aparece aqui é só uma PRÉVIA: quem calcula de verdade é
/// o banco, com a diária do carro (igual nas 3 plataformas).
class LocacaoPage extends StatefulWidget {
  const LocacaoPage({super.key});

  @override
  State<LocacaoPage> createState() => _LocacaoPageState();
}

class _LocacaoPageState extends State<LocacaoPage> {
  final _formKey = GlobalKey<FormState>();

  // A data de hoje, sem as horas (para as contas de dias darem certo)
  static DateTime get _hoje {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
  }

  int? _clienteSelecionadoId;
  int? _veiculoSelecionadoId;
  DateTime _dataRetirada = _hoje;
  DateTime _dataPrevista = _hoje.add(const Duration(days: 1));
  final _kmSaidaController = TextEditingController();
  final _observacoesController = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _kmSaidaController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Cliente? get _cliente {
    for (final c in clienteController.clientes) {
      if (c.id == _clienteSelecionadoId) return c;
    }
    return null;
  }

  Veiculo? get _veiculo {
    for (final v in frotaController.veiculosDisponiveis) {
      if (v.id == _veiculoSelecionadoId) return v;
    }
    return null;
  }

  /// Mesma conta do banco: mínimo de 1 diária.
  int get _dias {
    final dias = _dataPrevista.difference(_dataRetirada).inDays;
    return dias < 1 ? 1 : dias;
  }

  double get _valorPrevia => _dias * (_veiculo?.valorDiaria ?? 0);

  /// A CNH precisa valer até o fim do aluguel (regra do banco).
  String? get _avisoCnh {
    final cliente = _cliente;
    if (cliente == null) return null;
    if (cliente.cnhVencida) return 'A CNH de ${cliente.nome} está vencida. Atualize o cadastro antes de alugar.';
    if (cliente.cnhValidade.isBefore(_dataPrevista)) {
      return 'A CNH de ${cliente.nome} vence em ${dataBr(cliente.cnhValidade)}, antes do fim do aluguel.';
    }
    return null;
  }

  void _escolherVeiculo(int? id) {
    setState(() {
      _veiculoSelecionadoId = id;
      // A quilometragem de saída começa com a atual do carro
      final veiculo = _veiculo;
      if (veiculo != null) _kmSaidaController.text = '${veiculo.quilometragem}';
    });
  }

  /// Retirada: de hoje até 30 dias atrás (para registrar um aluguel esquecido).
  Future<void> _escolherRetirada() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _dataRetirada,
      firstDate: _hoje.subtract(const Duration(days: 30)),
      lastDate: _hoje,
      helpText: 'Data da retirada',
    );
    if (escolhida == null) return;

    setState(() {
      _dataRetirada = escolhida;
      if (_dataPrevista.isBefore(escolhida)) _dataPrevista = escolhida.add(const Duration(days: 1));
    });
  }

  /// Devolução prevista: de hoje até 365 dias depois da retirada.
  Future<void> _escolherPrevista() async {
    final primeira = _dataRetirada.isAfter(_hoje) ? _dataRetirada : _hoje;
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _dataPrevista.isBefore(primeira) ? primeira : _dataPrevista,
      firstDate: primeira,
      lastDate: _dataRetirada.add(const Duration(days: 365)),
      helpText: 'Devolução prevista',
    );
    if (escolhida != null) setState(() => _dataPrevista = escolhida);
  }

  void _avisar(String mensagem, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: cor, content: Text(mensagem)));
  }

  Future<void> _registrarLocacao() async {
    if (!_formKey.currentState!.validate()) return;

    final cliente = _cliente!;
    final veiculo = _veiculo!;

    // A assinatura do cliente vem ANTES de gravar: é o contrato sendo assinado
    final assinatura = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (context) => TelaAssinaturaDigital(tituloContrato: 'Contrato — ${cliente.nome}'),
      ),
    );
    if (assinatura == null) return; // desistiu de assinar

    setState(() => _salvando = true);
    try {
      final aluguel = await locacaoController.registrarAluguel(
        clienteId: cliente.id!,
        veiculoId: veiculo.id!,
        dataRetirada: _dataRetirada,
        dataPrevista: _dataPrevista,
        kmSaida: int.parse(soDigitos(_kmSaidaController.text)),
        observacoes: _observacoesController.text.trim().isEmpty ? null : _observacoesController.text.trim(),
        assinaturaPng: assinatura,
      );
      await frotaController.recarregar();

      if (mounted) await _mostrarConfirmacao(aluguel, cliente, veiculo, assinatura);
      if (mounted) Navigator.pop(context);
    } catch (erro) {
      // Ex.: "A CNH de Ana vence em 10/11/2026, antes do fim do aluguel."
      _avisar(erro.toString().replaceFirst('Exception: ', ''), RoyaleColors.statusAlugado);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// Aluguel registrado: mostra o número, o valor calculado pelo banco e
  /// oferece o contrato em PDF (já com a assinatura).
  Future<void> _mostrarConfirmacao(Locacao aluguel, Cliente cliente, Veiculo veiculo, Uint8List assinatura) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Aluguel #${aluguel.id} registrado'),
        content: Text(
          '${veiculo.nomeCompleto} (${veiculo.placaFormatada}) para ${cliente.nome}.\n\n'
          '${aluguel.diasPrevistos} diária(s) de ${moeda(aluguel.valorDiaria)}\n'
          'Total previsto: ${moeda(aluguel.valorPrevisto)}\n\n'
          'Contrato assinado e guardado. O carro já aparece como Alugado na web e no desktop.',
        ),
        actions: [
          TextButton(
            onPressed: () => ContratoPdf.gerarEAbrir(
              locacao: aluguel,
              cliente: cliente,
              veiculo: veiculo,
              assinaturaPng: assinatura,
            ),
            child: const Text('Ver contrato (PDF)'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  /// Campo de data que abre o calendário ao tocar.
  Widget _campoData(String rotulo, DateTime data, VoidCallback aoTocar) {
    return InkWell(
      onTap: aoTocar,
      child: InputDecorator(
        decoration: InputDecoration(labelText: rotulo, prefixIcon: const Icon(Icons.event)),
        child: Text(dataBr(data), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([clienteController, frotaController]),
      builder: (context, child) {
        final clientes = clienteController.clientes;
        final disponiveis = frotaController.veiculosDisponiveis;
        final veiculo = _veiculo;
        final avisoCnh = _avisoCnh;

        return Scaffold(
          appBar: AppBar(title: const AnimatedGoldenTitle("Nova Locação", fontSize: 24)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---------- Cliente ----------
                  if (clientes.isEmpty)
                    const Text('Cadastre um cliente antes de registrar uma locação.',
                        style: TextStyle(color: RoyaleColors.statusAlugado))
                  else
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Cliente *', prefixIcon: Icon(Icons.person)),
                      initialValue: _clienteSelecionadoId,
                      items: clientes
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                // CNH vencida: aparece, mas não dá para escolher
                                enabled: !c.cnhVencida,
                                child: Text(c.cnhVencida ? '${c.nome} (CNH vencida)' : c.nome,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (id) => setState(() => _clienteSelecionadoId = id),
                      validator: (id) => id == null ? 'Selecione um cliente' : null,
                    ),
                  if (avisoCnh != null) ...[
                    const SizedBox(height: 6),
                    Text(avisoCnh, style: const TextStyle(color: RoyaleColors.statusAlugado, fontSize: 12.5)),
                  ],
                  const SizedBox(height: 16),

                  // ---------- Veículo ----------
                  if (disponiveis.isEmpty)
                    const Text('Nenhum veículo disponível no momento.',
                        style: TextStyle(color: RoyaleColors.statusAlugado))
                  else
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Veículo disponível *', prefixIcon: Icon(Icons.directions_car)),
                      initialValue: _veiculoSelecionadoId,
                      items: disponiveis
                          .map((v) => DropdownMenuItem(
                                value: v.id,
                                child: Text('${v.nomeCompleto} (${v.placaFormatada}) — ${moeda(v.valorDiaria)}/dia',
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: _escolherVeiculo,
                      validator: (id) => id == null ? 'Selecione um veículo' : null,
                    ),
                  const SizedBox(height: 16),

                  // ---------- Quilometragem ----------
                  TextFormField(
                    controller: _kmSaidaController,
                    decoration: InputDecoration(
                      labelText: 'Quilometragem na retirada (km) *',
                      prefixIcon: const Icon(Icons.speed),
                      helperText: veiculo == null ? null : 'Atual do carro: ${veiculo.quilometragem} km',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final km = int.tryParse(soDigitos(v ?? ''));
                      if (km == null) return 'Informe a quilometragem de saída';
                      if (veiculo != null && km < veiculo.quilometragem) {
                        return 'Não pode ser menor que a atual (${veiculo.quilometragem} km)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ---------- Datas ----------
                  Row(
                    children: [
                      Expanded(child: _campoData('Retirada *', _dataRetirada, _escolherRetirada)),
                      const SizedBox(width: 12),
                      Expanded(child: _campoData('Devolução prevista *', _dataPrevista, _escolherPrevista)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _observacoesController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Observações (opcional)', prefixIcon: Icon(Icons.notes)),
                  ),
                  const SizedBox(height: 24),

                  // ---------- Prévia do valor ----------
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: RoyaleColors.azulMarinho, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        const Text("VALOR PREVISTO",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                        const SizedBox(height: 5),
                        Text(
                          moeda(_valorPrevia),
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: RoyaleColors.dourado),
                        ),
                        Text(
                          veiculo == null ? 'Escolha um veículo' : '$_dias diária(s) de ${moeda(veiculo.valorDiaria)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _salvando
                      ? const Center(child: CircularProgressIndicator(color: RoyaleColors.azulMarinho))
                      : RoyaleButton(
                          label: "Assinar contrato e confirmar",
                          // Com a CNH fora da validade, o banco recusaria: nem deixa tentar
                          onPressed: avisoCnh == null ? _registrarLocacao : null,
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
