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

/// 🌟 Carrega todos os dados da empresa logada (clientes, veículos,
/// locações ativas e laudos de manutenção). Só pode ser chamado DEPOIS
/// do login, porque antes disso não sabemos qual id_empresa filtrar
/// (o Supabase guarda os dados de todas as empresas na mesma tabela).
///
/// Cada área carrega de forma independente: se uma falhar (por
/// exemplo, a tabela `laudos_manutencao` ainda não existir porque a
/// migração SQL não foi rodada), as outras continuam funcionando
/// normalmente e o login não trava por completo.
Future<void> carregarDadosDaEmpresa(int idEmpresa) async {
  await Future.wait([
    _carregarComTolerancia('clientes', () => clienteController.carregarClientes(idEmpresa)),
    _carregarComTolerancia('veículos', () => frotaController.carregarVeiculos(idEmpresa)),
    _carregarComTolerancia('locações', () => locacaoController.carregarAtivas(idEmpresa)),
    _carregarComTolerancia('laudos de manutenção', () => manutencaoController.carregarLaudos(idEmpresa)),
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