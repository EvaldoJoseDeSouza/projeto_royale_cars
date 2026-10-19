import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../models/locacao.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../utils/contrato_pdf.dart';
import '../utils/permissoes.dart';
import '../utils/validadores.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_button.dart';
import '../widgets/royale_footer.dart';
import '../widgets/selo_status_locacao.dart';
import 'devolucao_page.dart';

/// Detalhes de um aluguel: cliente, carro, datas, valores, quem registrou,
/// a ASSINATURA do contrato (baixada do bucket "contratos") e os botões:
///   Registrar devolução  (locacoes_gerenciar, só em andamento)
///   Cancelar             (locacoes_cancelar, só em andamento)
///   Contrato (PDF)       (a qualquer momento)
///
/// Ao sair, devolve true se algo mudou (para a lista se atualizar).
class LocacaoDetalhesPage extends StatefulWidget {
  final Locacao locacao;

  const LocacaoDetalhesPage({super.key, required this.locacao});

  @override
  State<LocacaoDetalhesPage> createState() => _LocacaoDetalhesPageState();
}

class _LocacaoDetalhesPageState extends State<LocacaoDetalhesPage> {
  late final Future<Uint8List?> _assinatura = SupabaseService.instance.baixarAssinatura(widget.locacao.assinaturaPath);
  bool _ocupado = false;

  Locacao get _l => widget.locacao;

  void _avisar(String mensagem, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: cor, content: Text(mensagem)));
  }

  Future<void> _devolver() async {
    final mudou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => DevolucaoPage(locacao: _l)),
    );
    if (mudou == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _cancelar() async {
    final motivoController = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancelar o aluguel #${_l.id}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('O aluguel fica registrado como cancelado, sem cobrança, e o carro é liberado.'),
            const SizedBox(height: 12),
            TextField(
              controller: motivoController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Motivo *', hintText: 'Ex.: cliente desistiu'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Voltar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, motivoController.text.trim()),
            child: const Text('Cancelar aluguel', style: TextStyle(color: RoyaleColors.statusAlugado)),
          ),
        ],
      ),
    );
    // (Não damos dispose no motivoController aqui: a janela ainda está
    // fechando com animação e usaria um controller já descartado.)
    if (motivo == null) return; // voltou sem cancelar

    setState(() => _ocupado = true);
    try {
      await locacaoController.cancelar(_l.id, motivo);
      await frotaController.recarregar();
      _avisar('Aluguel #${_l.id} cancelado. O ${_l.nomeVeiculo} foi liberado.', RoyaleColors.statusDisponivel);
      if (mounted) Navigator.pop(context, true);
    } catch (erro) {
      // Ex.: "Informe o motivo do cancelamento." (o banco pede 5 letras ou mais)
      _avisar(erro.toString().replaceFirst('Exception: ', ''), RoyaleColors.statusAlugado);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _abrirContrato() async {
    await ContratoPdf.gerarEAbrir(locacao: _l, assinaturaPng: await _assinatura);
  }

  Widget _linha(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(rotulo, style: const TextStyle(color: RoyaleColors.textoMuted))),
          Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _cartao(String titulo, List<Widget> linhas) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, color: RoyaleColors.azulMarinho)),
            const Divider(),
            ...linhas,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final podeDevolver = _l.emAndamento && authController.pode(Permissao.locacoesGerenciar);
    final podeCancelar = _l.emAndamento && authController.pode(Permissao.locacoesCancelar);

    return Scaffold(
      appBar: AppBar(title: AnimatedGoldenTitle('Aluguel #${_l.id}', fontSize: 22)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [SeloStatusLocacao(statusExibicao: _l.statusExibicao)]),
          const SizedBox(height: 12),
          _cartao('Cliente', [
            _linha('Nome', _l.nomeCliente),
            _linha('CPF', mascaraCpf(_l.cpfCliente)),
            _linha('Telefone', mascaraTelefone(_l.telefoneCliente)),
          ]),
          _cartao('Veículo', [
            _linha('Carro', '${_l.nomeVeiculo}${_l.ano > 0 ? ' ${_l.ano}' : ''}'),
            _linha('Placa', _l.placaFormatada),
            _linha('Km na saída', _l.kmSaida == null ? '—' : '${_l.kmSaida} km'),
            if (_l.kmRetorno != null) _linha('Km na volta', '${_l.kmRetorno} km (${_l.kmRodados} km rodados)'),
          ]),
          _cartao('Período e valores', [
            _linha('Retirada', dataBr(_l.dataRetirada)),
            _linha('Prevista', dataBr(_l.dataPrevista)),
            if (_l.dataDevolucao != null) _linha('Devolvido em', dataBr(_l.dataDevolucao!)),
            _linha('Diária', moeda(_l.valorDiaria)),
            _linha('Previsto', '${moeda(_l.valorPrevisto)} (${_l.diasPrevistos} diária(s))'),
            if (_l.diasAtraso > 0) _linha('Atraso', '${_l.diasAtraso} dia(s): ${moeda(_l.valorAtraso)}'),
            if (_l.taxasExtras > 0) _linha('Taxas extras', '${moeda(_l.taxasExtras)} (${_l.taxasMotivo ?? ''})'),
            _linha('Total', moeda(_l.valorTotal)),
            if (_l.observacoes != null) _linha('Observações', _l.observacoes!),
          ]),
          _cartao('Atendimento', [
            _linha('Registrado por', _l.registradoPor ?? '—'),
            if (!_l.emAndamento) _linha('Encerrado por', _l.encerradoPor ?? '—'),
          ]),

          // ----- A assinatura colhida no celular -----
          _cartao('Assinatura do contrato', [
            if (!_l.temAssinatura)
              const Text('Este aluguel não tem assinatura (foi registrado sem ela).',
                  style: TextStyle(color: RoyaleColors.textoMuted))
            else
              FutureBuilder<Uint8List?>(
                future: _assinatura,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(color: RoyaleColors.azulMarinho)),
                    );
                  }
                  final imagem = snapshot.data;
                  if (imagem == null) {
                    return const Text('Não foi possível carregar a assinatura agora.',
                        style: TextStyle(color: RoyaleColors.textoMuted));
                  }
                  return Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: RoyaleColors.bordaClara),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.memory(imagem, fit: BoxFit.contain),
                  );
                },
              ),
          ]),
          const SizedBox(height: 8),

          // ----- Ações -----
          if (_ocupado)
            const Center(child: CircularProgressIndicator(color: RoyaleColors.azulMarinho))
          else ...[
            if (podeDevolver) RoyaleButton(label: 'Registrar devolução', onPressed: _devolver, fullWidth: true),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _abrirContrato,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Contrato (PDF)'),
            ),
            if (podeCancelar) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _cancelar,
                icon: const Icon(Icons.cancel_outlined, color: RoyaleColors.statusAlugado),
                label: const Text('Cancelar aluguel', style: TextStyle(color: RoyaleColors.statusAlugado)),
              ),
            ],
          ],
        ],
      ),
      bottomNavigationBar: const RoyaleFooter(),
    );
  }
}
