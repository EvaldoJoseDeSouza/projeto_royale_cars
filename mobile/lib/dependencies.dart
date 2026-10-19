import 'package:flutter/foundation.dart';

import 'controllers/auth_controller.dart';
import 'controllers/cliente_controller.dart';
import 'controllers/frota_controller.dart';
import 'controllers/locacao_controller.dart';
import 'controllers/manutencao_controller.dart';

// Central de controle global do aplicativo Royale Cars
final authController = AuthController();
final clienteController = ClienteController();
final frotaController = FrotaController();
final locacaoController = LocacaoController();
final manutencaoController = ManutencaoController();

/// Carrega os dados que as telas usam (clientes, veículos, locações em
/// andamento e manutenções). Só pode ser chamado DEPOIS do login: sem
/// login, o banco não entrega nada (cada pessoa só vê o que as
/// permissões dela deixam).
///
/// Cada área carrega de forma independente: se uma falhar, as outras
/// continuam funcionando e o login não trava por completo.
Future<void> carregarDados() async {
  await Future.wait([
    _carregarComTolerancia('clientes', clienteController.carregarClientes),
    _carregarComTolerancia('veículos', frotaController.carregarVeiculos),
    _carregarComTolerancia('locações', locacaoController.carregarAtivas),
    _carregarComTolerancia('manutenções', manutencaoController.carregar),
  ]);
}

Future<void> _carregarComTolerancia(String nomeArea, Future<void> Function() carregar) async {
  try {
    await carregar();
  } catch (erro) {
    // Não interrompe o login por causa de uma área com problema —
    // só avisa no console (visível no terminal do `flutter run`).
    debugPrint('[CARREGAMENTO] Falha ao carregar "$nomeArea": $erro');
  }
}