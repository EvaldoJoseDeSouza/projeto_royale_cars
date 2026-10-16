import 'package:supabase_flutter/supabase_flutter.dart';

// =====================================================================
//  Tradutor dos erros do banco (o mesmo do desktop: erros-banco.js)
// ---------------------------------------------------------------------
//  O banco (Supabase/PostgreSQL) é o "juiz final": ele confere CPF,
//  CNH, telefone, duplicados, aluguel em andamento etc. Quando recusa,
//  devolve um erro técnico, em inglês. Ex.:
//
//    code: "23505"
//    message: 'duplicate key value violates unique constraint "clientes_cpf_key"'
//
//  Este arquivo transforma isso numa frase para a pessoa ler na tela.
//
//  Os códigos que importam (são padrão do PostgreSQL):
//    23505 → valor repetido (UNIQUE): CPF, placa, e-mail já cadastrados
//    23514 → regra da tabela não aceitou (CHECK): CPF inválido, placa errada...
//    23502 → campo obrigatório vazio (NOT NULL)
//    P0001 → mensagem escrita por nós nas funções do banco (já em português)
//    42501 → sem permissão (RLS)
// =====================================================================

const mensagemSemConexao = 'Não foi possível conectar ao servidor. Verifique a internet e tente de novo.';

/// Descobre o nome da regra que falhou. Ex.: "clientes_cpf_key"
String nomeDaRegra(PostgrestException erro) {
  final texto = '${erro.message} ${erro.details ?? ''}';
  final achado = RegExp(r'constraint "([^"]+)"').firstMatch(texto);
  return achado?.group(1) ?? '';
}

/// Devolve sempre uma frase pronta para mostrar.
/// [mensagens] é um "dicionário" { nomeDaRegra: frase } de cada tela.
String traduzirErroBanco(Object erro, [Map<String, String> mensagens = const {}]) {
  // Erro do banco (tabelas e funções)
  if (erro is PostgrestException) {
    final regra = nomeDaRegra(erro);
    if (regra.isNotEmpty && mensagens.containsKey(regra)) return mensagens[regra]!;

    return switch (erro.code) {
      'P0001' => erro.message, // escrita por nós no banco, já está em português
      '23505' => 'Já existe um cadastro com estes dados.',
      '23514' || '23502' => 'Algum campo não passou na conferência do banco. Confira os dados digitados.',
      '42501' => 'Você não tem permissão para fazer isso.',
      _ => mensagemSemConexao,
    };
  }

  // Sem internet no login: o Supabase Auth avisa com este tipo de erro
  if (erro is AuthRetryableFetchException) return mensagemSemConexao;

  // Mensagem que nós mesmos montamos com Exception('frase')
  final texto = erro.toString();
  if (texto.startsWith('Exception: ')) return texto.replaceFirst('Exception: ', '');

  // Qualquer outra coisa (sem internet, servidor fora do ar...)
  return mensagemSemConexao;
}
