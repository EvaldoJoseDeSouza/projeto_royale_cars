import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../services/supabase_service.dart';

/// Controla o usuário logado e a "empresa" (id_empresa) ativa —
/// mesmo modelo multi-tenant do desktop: cada conta de e-mail é uma
/// empresa, e todos os dados (clientes, veículos, locações) ficam
/// isolados por id_empresa.
class AuthController extends ChangeNotifier {
  Usuario? _usuarioLogado;

  Usuario? get usuarioLogado => _usuarioLogado;
  bool get estaLogado => _usuarioLogado != null;
  int? get idEmpresa => _usuarioLogado?.idEmpresa;

  Future<void> login(String loginOuEmail, String senha) async {
    final usuario = await SupabaseService.instance.login(loginOuEmail, senha);
    _usuarioLogado = usuario;
    notifyListeners();
  }

  Future<void> criarConta({
    required String username,
    required String email,
    required String senha,
  }) async {
    await SupabaseService.instance.criarConta(username: username, email: email, senha: senha);
  }

  Future<void> trocarSenha({required String senhaAtual, required String novaSenha}) async {
    if (_usuarioLogado == null) throw Exception('Sessão expirada.');
    await SupabaseService.instance.trocarSenha(
      usuarioLogado: _usuarioLogado!,
      senhaAtual: senhaAtual,
      novaSenha: novaSenha,
    );
  }

  void logout() {
    _usuarioLogado = null;
    notifyListeners();
  }
}
