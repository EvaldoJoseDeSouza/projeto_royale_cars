import '../utils/validadores.dart';

/// Cliente da locadora. Segue a tabela `clientes` do banco unificado
/// (a mesma da web e do desktop).
///
/// O banco guarda CPF, CNH e telefone SÓ COM NÚMEROS ("52998224725").
/// A máscara (529.982.247-25) é só para mostrar na tela: veja os
/// "get" cpfFormatado e telefoneFormatado lá embaixo.
class Cliente {
  final int? id; // null = cliente novo, ainda não salvo
  final String nome;
  final String cpf;
  final String cnh;
  final DateTime cnhValidade;
  final String email;
  final String telefone;
  final String? endereco; // opcional
  final bool arquivado; // "arquivar" esconde da lista sem apagar o histórico

  /// As colunas que as telas usam (nunca "select *": só o que precisa)
  static const colunas = 'id, nome, cpf, cnh, cnh_validade, email, telefone, endereco, arquivado';

  const Cliente({
    this.id,
    required this.nome,
    required this.cpf,
    required this.cnh,
    required this.cnhValidade,
    required this.email,
    required this.telefone,
    this.endereco,
    this.arquivado = false,
  });

  String get cpfFormatado => mascaraCpf(cpf);
  String get telefoneFormatado => mascaraTelefone(telefone);

  /// Quantos dias faltam para a CNH vencer (negativo = já venceu).
  int get diasParaVencerCnh {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    return cnhValidade.difference(hoje).inDays;
  }

  bool get cnhVencida => diasParaVencerCnh < 0;

  /// Lê uma linha que veio do banco.
  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}'),
      nome: '${map['nome'] ?? ''}',
      cpf: '${map['cpf'] ?? ''}',
      cnh: '${map['cnh'] ?? ''}',
      cnhValidade: DateTime.tryParse('${map['cnh_validade']}') ?? DateTime.now(),
      email: '${map['email'] ?? ''}',
      telefone: '${map['telefone'] ?? ''}',
      endereco: map['endereco'] as String?,
      arquivado: map['arquivado'] == true,
    );
  }

  /// O que vai para o banco ao cadastrar ou editar: os dados já
  /// "limpos" (só números no CPF, CNH e telefone; e-mail minúsculo).
  /// O banco limpa de novo e confere tudo; aqui é só para chegar certo.
  Map<String, dynamic> toMap() {
    final enderecoLimpo = (endereco ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');

    return {
      'nome': nome.trim().replaceAll(RegExp(r'\s+'), ' '),
      'cpf': soDigitos(cpf),
      'cnh': soDigitos(cnh),
      'cnh_validade': dataParaBanco(cnhValidade),
      'email': email.trim().toLowerCase(),
      'telefone': soDigitos(telefone),
      'endereco': enderecoLimpo.isEmpty ? null : enderecoLimpo,
    };
  }
}
