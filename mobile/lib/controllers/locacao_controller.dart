import 'package:flutter/foundation.dart';
import '../models/locacao.dart';
import '../services/supabase_service.dart';

/// Guarda os aluguéis (em andamento e o histórico) e avisa as telas
/// quando eles mudam.
class LocacaoController extends ChangeNotifier {
  List<Locacao> _ativas = [];
  List<Locacao> _historico = [];
  bool isLoading = false;

  List<Locacao> get locacoesAtivas => List.unmodifiable(_ativas);
  List<Locacao> get historico => List.unmodifiable(_historico);

  Future<void> carregarAtivas() async {
    isLoading = true;
    notifyListeners();
    try {
      _ativas = await SupabaseService.instance.buscarLocacoesAtivas();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> carregarHistorico() async {
    _historico = await SupabaseService.instance.buscarLocacoesHistorico();
    notifyListeners();
  }

  /// A retirada completa, em 2 passos:
  ///  1. guarda a assinatura (PNG) no bucket "contratos";
  ///  2. chama registrar_aluguel com o caminho da assinatura.
  /// Devolve o aluguel recém-criado (já com o valor calculado pelo banco).
  Future<Locacao> registrarAluguel({
    required int clienteId,
    required int veiculoId,
    required DateTime dataRetirada,
    required DateTime dataPrevista,
    required int kmSaida,
    required Uint8List assinaturaPng,
    String? observacoes,
  }) async {
    final servico = SupabaseService.instance;

    final caminho = await servico.enviarAssinatura(assinaturaPng, clienteId);

    final id = await servico.registrarAluguel(
      clienteId: clienteId,
      veiculoId: veiculoId,
      dataRetirada: dataRetirada,
      dataPrevista: dataPrevista,
      kmSaida: kmSaida,
      observacoes: observacoes,
      assinaturaPath: caminho,
    );

    await carregarAtivas();
    return _ativas.firstWhere((l) => l.id == id);
  }

  /// A devolução pelo celular chega no pacote 4.6.
  Future<void> finalizarLocacao({
    required int idLocacao,
    required int idVeiculo,
    int? kmRetorno,
    double? novoValorTotal,
  }) async {
    await SupabaseService.instance.finalizarLocacao(
      idLocacao: idLocacao,
      idVeiculo: idVeiculo,
      kmRetorno: kmRetorno,
      novoValorTotal: novoValorTotal,
    );
  }
}
