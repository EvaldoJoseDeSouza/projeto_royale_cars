import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../services/supabase_service.dart';

/// Guarda quem está logado e o que essa pessoa pode fazer.
///
/// Não existe mais "empresa" (id_empresa): a locadora é uma só e o
/// banco decide o que cada pessoa vê pelas permissões dela (RLS).
class AuthController extends ChangeNotifier {
  Usuario? _usuario;

  Usuario? get usuario => _usuario;
  bool get estaLogado => _usuario != null;

  /// Atalho para as telas: authController.pode('clientes_gerenciar')
  bool pode(String permissao) => _usuario?.pode(permissao) ?? false;

  /// Login com e-mail e senha (o roteiro completo fica no SupabaseService).
  Future<void> entrar(String email, String senha) async {
    _usuario = await SupabaseService.instance.entrar(email.trim().toLowerCase(), senha);
    notifyListeners();
  }

  /// O app abriu e já havia uma sessão salva no aparelho: pergunta de
  /// novo ao banco o perfil e as permissões (podem ter mudado, ou a
  /// pessoa pode ter sido desativada enquanto o app estava fechado).
  Future<void> retomarSessao() async {
    _usuario = await SupabaseService.instance.carregarSessao();
    notifyListeners();
  }

  /// Troca normal (sabe a senha atual).
  Future<void> trocarSenha({required String senhaAtual, required String novaSenha}) async {
    final usuario = _usuario;
    if (usuario == null) throw Exception('Sua sessão terminou. Entre novamente.');

    await SupabaseService.instance.trocarSenha(
      email: usuario.email,
      senhaAtual: senhaAtual,
      novaSenha: novaSenha,
    );
    _usuario = usuario.semTrocaDeSenha();
    notifyListeners();
  }

  /// Troca obrigatória: a pessoa acabou de entrar com a senha temporária
  /// que o chefe gerou, então não pedimos a senha atual de novo.
  Future<void> criarSenhaPropria(String novaSenha) async {
    final usuario = _usuario;
    if (usuario == null || !usuario.trocarSenha) throw Exception('Sua sessão terminou. Entre novamente.');

    await SupabaseService.instance.gravarNovaSenha(novaSenha);
    _usuario = usuario.semTrocaDeSenha();
    notifyListeners();
  }

  /// Minha conta: a pessoa muda o próprio nome (o resto só o chefe muda).
  Future<void> salvarNome(String nome) async {
    final usuario = _usuario;
    if (usuario == null) throw Exception('Sua sessão terminou. Entre novamente.');

    final nomeLimpo = nome.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (nomeLimpo.length < 3 || nomeLimpo.length > 100) {
      throw Exception('O nome precisa ter entre 3 e 100 caracteres.');
    }

    await SupabaseService.instance.salvarMeuNome(usuario.id, nomeLimpo);
    _usuario = usuario.comNome(nomeLimpo);
    notifyListeners();
  }

  Future<void> sair() async {
    await SupabaseService.instance.sair();
    _usuario = null;
    notifyListeners();
  }
}
