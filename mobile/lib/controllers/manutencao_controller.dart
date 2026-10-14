import 'package:flutter/material.dart';
import '../models/laudo_manutencao.dart';
import '../services/supabase_service.dart';

class ManutencaoController extends ChangeNotifier {
  List<LaudoManutencao> _laudos = [];
  bool isLoading = false;

  List<LaudoManutencao> get laudos => List.unmodifiable(_laudos);

  Future<void> carregarLaudos(int idEmpresa) async {
    isLoading = true;
    notifyListeners();
    try {
      _laudos = await SupabaseService.instance.buscarLaudos(idEmpresa);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> salvarLaudo(LaudoManutencao laudo, int idEmpresa) async {
    await SupabaseService.instance.salvarLaudo(laudo, idEmpresa);
    await carregarLaudos(idEmpresa);
  }

  Future<void> concluirManutencao(int idVeiculo, int idEmpresa) async {
    await SupabaseService.instance.concluirManutencao(idVeiculo);
    await carregarLaudos(idEmpresa);
  }
}
