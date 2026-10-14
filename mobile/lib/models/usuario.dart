/// Usuário do sistema. Segue exatamente a tabela `usuarios` do Supabase
/// já usada pelo app desktop: cada conta representa uma empresa
/// (multi-tenant), identificada por `idEmpresa` — que é o próprio `id`
/// do usuário "Proprietário" que criou a conta.
class Usuario {
  final int? id;
  final String username;
  final String email;
  final String senha; // hash bcrypt, como vem do banco
  final int? idEmpresa;

  Usuario({
    this.id,
    required this.username,
    required this.email,
    required this.senha,
    this.idEmpresa,
  });

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}'),
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      senha: map['senha'] ?? '',
      idEmpresa: map['id_empresa'] is int
          ? map['id_empresa'] as int
          : int.tryParse('${map['id_empresa']}'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'senha': senha,
      if (idEmpresa != null) 'id_empresa': idEmpresa,
    };
  }
}
