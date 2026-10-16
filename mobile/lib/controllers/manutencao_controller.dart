import 'package:flutter/material.dart';
import '../models/laudo_manutencao.dart';
import '../services/supabase_service.dart';

class ManutencaoController extends ChangeNotifier {
  List<LaudoManutencao> _laudos = [];
  bool isLoading = false;

  List<LaudoManutencao> get laudos => List.unmodifiable(_laudos);

  Future<void> carregarLaudos() async {
    isLoading = true;
    notifyListeners();
    try {
      _laudos = await SupabaseService.instance.buscarLaudos();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> salvarLaudo(LaudoManutencao laudo) async {
    await SupabaseService.instance.salvarLaudo(laudo);
    await carregarLaudos();
  }

  Future<void> concluirManutencao(int idVeiculo) async {
    await SupabaseService.instance.concluirManutencao(idVeiculo);
    await carregarLaudos();
  }
}
