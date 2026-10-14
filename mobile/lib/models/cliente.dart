/// Cliente da locadora. Segue a tabela `clientes` do Supabase (mesma
/// usada pelo desktop): nome, cpf, cnh, telefone, email, endereço —
/// mais o multi-tenant `idEmpresa` e a flag `ativo` (exclusão lógica,
/// usada pelo botão "Arquivar" tanto no desktop quanto aqui).
class Cliente {
  final int? id;
  final int? idEmpresa;
  final String nome;
  final String cpf;
  final String cnh;
  final String telefone;
  final String? email;
  final String? endereco;
  final bool ativo;

  Cliente({
    this.id,
    this.idEmpresa,
    required this.nome,
    required this.cpf,
    required this.cnh,
    required this.telefone,
    this.email,
    this.endereco,
    this.ativo = true,
  });

  Cliente copyWith({
    int? id,
    int? idEmpresa,
    String? nome,
    String? cpf,
    String? cnh,
    String? telefone,
    String? email,
    String? endereco,
    bool? ativo,
  }) {
    return Cliente(
      id: id ?? this.id,
      idEmpresa: idEmpresa ?? this.idEmpresa,
      nome: nome ?? this.nome,
      cpf: cpf ?? this.cpf,
      cnh: cnh ?? this.cnh,
      telefone: telefone ?? this.telefone,
      email: email ?? this.email,
      endereco: endereco ?? this.endereco,
      ativo: ativo ?? this.ativo,
    );
  }

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}'),
      idEmpresa: map['id_empresa'] is int
          ? map['id_empresa'] as int
          : int.tryParse('${map['id_empresa']}'),
      nome: map['nome'] ?? '',
      cpf: map['cpf'] ?? '',
      cnh: map['cnh'] ?? '',
      telefone: map['telefone'] ?? '',
      email: map['email'],
      endereco: map['endereco'],
      ativo: map['ativo'] is bool ? map['ativo'] as bool : (map['ativo'] == null ? true : map['ativo'].toString() == 'true'),
    );
  }

  /// Formato de envio para o Supabase (sem o id — o id_empresa é
  /// adicionado pelo SupabaseService na hora de inserir).
  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'cpf': cpf,
      'cnh': cnh,
      'telefone': telefone,
      'email': email,
      'endereco': endereco,
    };
  }
}
