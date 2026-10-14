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

  Future<void> carregarVeiculos(int idEmpresa) async {
    isLoading = true;
    notifyListeners();
    try {
      _veiculos = await SupabaseService.instance.buscarFrota(idEmpresa);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> carregarVeiculosArquivados(int idEmpresa) async {
    _veiculosArquivados = await SupabaseService.instance.buscarFrotaArquivada(idEmpresa);
    notifyListeners();
  }

  Future<void> salvarVeiculo(Veiculo veiculo, int idEmpresa) async {
    await SupabaseService.instance.salvarVeiculo(veiculo, idEmpresa);
    await carregarVeiculos(idEmpresa);
  }

  Future<void> arquivarVeiculo(int idVeiculo, int idEmpresa) async {
    await SupabaseService.instance.arquivarVeiculo(idVeiculo);
    await carregarVeiculos(idEmpresa);
  }

  Future<void> reativarVeiculo(int idVeiculo, int idEmpresa) async {
    await SupabaseService.instance.reativarVeiculo(idVeiculo);
    await carregarVeiculosArquivados(idEmpresa);
    await carregarVeiculos(idEmpresa);
  }

  /// Recarrega a frota silenciosamente (usado depois de registrar uma
  /// locação/devolução/manutenção, pra refletir a mudança de status).
  Future<void> recarregar(int idEmpresa) => carregarVeiculos(idEmpresa);
}
