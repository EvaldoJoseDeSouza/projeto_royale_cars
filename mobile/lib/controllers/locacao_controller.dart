import 'package:flutter/foundation.dart';
import '../models/locacao.dart';
import '../services/supabase_service.dart';
import '../utils/atualizar_sem_falhar.dart';

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

    // Já gravou: se a lista não recarregar, busca só este aluguel
    await atualizarSemFalhar(carregarAtivas);
    final daLista = _ativas.where((l) => l.id == id);
    if (daLista.isNotEmpty) return daLista.first;
    return servico.buscarLocacao(id);
  }

  /// Lista de uma aba da tela de Locações ("Em andamento", "Atrasados"...).
  Future<List<Locacao>> listar(String aba) => SupabaseService.instance.buscarLocacoes(aba);

  /// Devolução pela função do banco. Devolve o resumo que o banco calculou.
  Future<Map<String, dynamic>> devolver({
    required int locacaoId,
    required DateTime dataDevolucao,
    int? kmRetorno,
    double taxasExtras = 0,
    String? taxasMotivo,
    String? observacoes,
    String? defeito,
    String? oficina,
  }) async {
    final resumo = await SupabaseService.instance.registrarDevolucao(
      locacaoId: locacaoId,
      dataDevolucao: dataDevolucao,
      kmRetorno: kmRetorno,
      taxasExtras: taxasExtras,
      taxasMotivo: taxasMotivo,
      observacoes: observacoes,
      defeito: defeito,
      oficina: oficina,
    );
    await atualizarSemFalhar(carregarAtivas);
    return resumo;
  }

  Future<void> cancelar(int locacaoId, String motivo) async {
    await SupabaseService.instance.cancelarAluguel(locacaoId, motivo);
    await atualizarSemFalhar(carregarAtivas);
  }
}
