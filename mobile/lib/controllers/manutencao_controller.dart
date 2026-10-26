import 'package:flutter/material.dart';
import '../models/manutencao.dart';
import '../services/supabase_service.dart';
import '../utils/atualizar_sem_falhar.dart';

/// Guarda as manutenções (carros na oficina e o histórico) e avisa as
/// telas quando elas mudam.
class ManutencaoController extends ChangeNotifier {
  List<Manutencao> _naOficina = [];
  List<Manutencao> _concluidas = [];
  bool isLoading = false;

  List<Manutencao> get naOficina => List.unmodifiable(_naOficina);
  List<Manutencao> get concluidas => List.unmodifiable(_concluidas);

  /// Carrega as duas listas de uma vez.
  Future<void> carregar() async {
    isLoading = true;
    notifyListeners();
    try {
      final servico = SupabaseService.instance;
      final listas = await Future.wait([
        servico.buscarManutencoes(emAndamento: true),
        servico.buscarManutencoes(emAndamento: false),
      ]);
      _naOficina = listas[0];
      _concluidas = listas[1];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> enviarParaOficina({
    required int veiculoId,
    required String defeito,
    String? oficina,
    required DateTime dataEntrada,
    DateTime? previsao,
    List<bool?> checklist = const [null, null, null, null],
  }) async {
    await SupabaseService.instance.abrirManutencao(
      veiculoId: veiculoId,
      defeito: defeito,
      oficina: oficina,
      dataEntrada: dataEntrada,
      previsao: previsao,
      checklist: checklist,
    );
    await atualizarSemFalhar(carregar);
  }

  Future<void> liberar({
    required int manutencaoId,
    required DateTime dataLiberacao,
    required String servico,
    required double custo,
  }) async {
    await SupabaseService.instance.concluirManutencao(
      manutencaoId: manutencaoId,
      dataLiberacao: dataLiberacao,
      servico: servico,
      custo: custo,
    );
    await atualizarSemFalhar(carregar);
  }
}
