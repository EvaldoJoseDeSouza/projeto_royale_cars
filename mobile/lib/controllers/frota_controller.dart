import 'package:flutter/material.dart';
import '../models/veiculo.dart';
import '../services/supabase_service.dart';

class FrotaController extends ChangeNotifier {
  List<Veiculo> _veiculos = [];
  List<Veiculo> _veiculosArquivados = [];
  bool isLoading = false;

  List<Veiculo> get veiculos => List.unmodifiable(_veiculos);
  List<Veiculo> get veiculosArquivados => List.unmodifiable(_veiculosArquivados);
  List<Veiculo> get veiculosDisponiveis =>
      _veiculos.where((v) => v.status == Veiculo.statusDisponivel).toList();

  Future<void> carregarVeiculos() async {
    isLoading = true;
    notifyListeners();
    try {
      _veiculos = await SupabaseService.instance.buscarFrota();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> carregarVeiculosArquivados() async {
    _veiculosArquivados = await SupabaseService.instance.buscarFrotaArquivada();
    notifyListeners();
  }

  Future<void> salvarVeiculo(Veiculo veiculo) async {
    await SupabaseService.instance.salvarVeiculo(veiculo);
    await carregarVeiculos();
  }

  Future<void> arquivarVeiculo(int idVeiculo) async {
    await SupabaseService.instance.arquivarVeiculo(idVeiculo);
    await carregarVeiculos();
  }

  Future<void> reativarVeiculo(int idVeiculo) async {
    await SupabaseService.instance.reativarVeiculo(idVeiculo);
    await carregarVeiculosArquivados();
    await carregarVeiculos();
  }

  /// Recarrega a frota silenciosamente (usado depois de registrar uma
  /// locação/devolução/manutenção, pra refletir a mudança de status).
  Future<void> recarregar() => carregarVeiculos();
}
