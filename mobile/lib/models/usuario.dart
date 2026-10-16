/// Quem está usando o app. Os dados vêm prontos da função
/// `iniciar_sessao` do banco (a mesma que a web e o desktop chamam logo
/// depois do login): perfil + lista de permissões.
///
/// A senha NÃO fica aqui: quem guarda e confere a senha é o Supabase
/// Auth. O app nunca vê nem o hash.
class Usuario {
  final String id; // uuid do Supabase Auth (ex.: "3f2a...-...")
  final String nome;
  final String email;
  final String cargo; // 'chefe' | 'gerente' | 'funcionario'
  final bool trocarSenha; // true = senha temporária, precisa criar uma nova
  final Set<String> permissoes; // ex.: {'clientes_ver', 'locacoes_gerenciar'}

  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.cargo,
    required this.trocarSenha,
    required this.permissoes,
  });

  bool get ehChefe => cargo == 'chefe';

  /// O usuário tem a permissão? (o chefe tem todas)
  bool pode(String permissao) => ehChefe || permissoes.contains(permissao);

  /// Nome do cargo para mostrar na tela.
  String get cargoTexto => switch (cargo) {
        'chefe' => 'Chefe',
        'gerente' => 'Gerente',
        _ => 'Funcionário',
      };

  /// Monta o usuário a partir da resposta de `iniciar_sessao`:
  /// {"id": "...", "nome": "...", "email": "...", "cargo": "gerente",
  ///  "trocar_senha": false, "permissoes": ["clientes_ver", ...]}
  factory Usuario.fromSessao(Map<String, dynamic> dados) {
    final lista = dados['permissoes'];

    return Usuario(
      id: '${dados['id']}',
      nome: '${dados['nome'] ?? ''}',
      email: '${dados['email'] ?? ''}',
      cargo: '${dados['cargo'] ?? 'funcionario'}',
      trocarSenha: dados['trocar_senha'] == true,
      permissoes: lista is List ? lista.map((p) => '$p').toSet() : <String>{},
    );
  }

  /// Cópia com a marca de "trocar senha" desligada (depois da troca).
  Usuario semTrocaDeSenha() => Usuario(
        id: id,
        nome: nome,
        email: email,
        cargo: cargo,
        trocarSenha: false,
        permissoes: permissoes,
      );
}
