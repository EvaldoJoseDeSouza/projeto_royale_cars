import 'package:flutter/material.dart';
import '../models/veiculo.dart';
import '../services/supabase_service.dart';

/// Guarda as listas da frota (ativa e arquivada) e avisa as telas
/// quando elas mudam.
class FrotaController extends ChangeNotifier {
  List<Veiculo> _veiculos = [];
  List<Veiculo> _veiculosArquivados = [];
  bool isLoading = false;

  List<Veiculo> get veiculos => List.unmodifiable(_veiculos);
  List<Veiculo> get veiculosArquivados => List.unmodifiable(_veiculosArquivados);
  List<Veiculo> get veiculosDisponiveis => _veiculos.where((v) => v.isDisponivel).toList();

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
    _veiculosArquivados = await SupabaseService.instance.buscarFrota(arquivados: true);
    notifyListeners();
  }

  /// Salva e devolve a frase para mostrar na tela.
  Future<String> salvarVeiculo(Veiculo veiculo) async {
    await SupabaseService.instance.salvarVeiculo(veiculo);
    await carregarVeiculos();
    return veiculo.id != null
        ? 'O ${veiculo.nomeCompleto} foi atualizado.'
        : 'O ${veiculo.nomeCompleto} entrou na frota como Disponível.';
  }

  Future<String> arquivarVeiculo(int idVeiculo) async {
    final veiculo = await SupabaseService.instance.mudarArquivadoVeiculo(idVeiculo, true);
    await carregarVeiculos();
    return 'O ${veiculo.nomeCompleto} saiu da frota. O histórico de locações continua guardado.';
  }

  Future<String> reativarVeiculo(int idVeiculo) async {
    final veiculo = await SupabaseService.instance.mudarArquivadoVeiculo(idVeiculo, false);
    await Future.wait([carregarVeiculosArquivados(), carregarVeiculos()]);
    return 'O ${veiculo.nomeCompleto} voltou para a frota como Disponível.';
  }

  /// Recarrega a frota (usado depois de uma locação, devolução ou
  /// manutenção, para mostrar o status novo).
  Future<void> recarregar() => carregarVeiculos();
}
