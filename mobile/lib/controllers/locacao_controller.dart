import 'package:flutter/material.dart';
import '../models/locacao.dart';
import '../services/supabase_service.dart';

class LocacaoController extends ChangeNotifier {
  List<Locacao> _ativas = [];
  List<Locacao> _historico = [];
  bool isLoading = false;

  List<Locacao> get locacoesAtivas => List.unmodifiable(_ativas);
  List<Locacao> get historico => List.unmodifiable(_historico);

  Future<void> carregarAtivas(int idEmpresa) async {
    isLoading = true;
    notifyListeners();
    try {
      _ativas = await SupabaseService.instance.buscarLocacoesAtivas(idEmpresa);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> carregarHistorico(int idEmpresa) async {
    _historico = await SupabaseService.instance.buscarLocacoesHistorico(idEmpresa);
    notifyListeners();
  }

  Future<void> registrarLocacao(Locacao locacao, int idEmpresa) async {
    await SupabaseService.instance.salvarLocacao(locacao, idEmpresa);
    await carregarAtivas(idEmpresa);
  }

  Future<void> finalizarLocacao({
    required int idLocacao,
    required int idVeiculo,
    required int idEmpresa,
    int? kmRetorno,
    String? assinaturaBase64,
    double? novoValorTotal,
  }) async {
    await SupabaseService.instance.finalizarLocacao(
      idLocacao: idLocacao,
      idVeiculo: idVeiculo,
      kmRetorno: kmRetorno,
      assinaturaBase64: assinaturaBase64,
      novoValorTotal: novoValorTotal,
    );
    await carregarAtivas(idEmpresa);
    await carregarHistorico(idEmpresa);
  }
}
