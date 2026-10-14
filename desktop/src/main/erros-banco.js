// =====================================================================
//  Tradutor dos erros do banco
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

// Descobre o nome da regra que falhou. Ex.: "clientes_cpf_key"
function nomeDaRegra(erro) {
  const texto = `${erro.message || ""} ${erro.details || ""}`;
  const achado = texto.match(/constraint "([^"]+)"/);
  return achado ? achado[1] : "";
}

// mensagens: um "dicionário" { nomeDaRegra: "frase" } de cada tela.
// Devolve sempre uma frase pronta para mostrar.
function traduzirErroBanco(erro, mensagens = {}) {
  if (!erro) return "";

  const regra = nomeDaRegra(erro);
  if (regra && mensagens[regra]) return mensagens[regra];

  switch (erro.code) {
    case "P0001":
      return erro.message; // escrita por nós no banco, já está em português
    case "23505":
      return "Já existe um cadastro com estes dados.";
    case "23514":
    case "23502":
      return "Algum campo não passou na conferência do banco. Confira os dados digitados.";
    case "42501":
      return "Você não tem permissão para fazer isso.";
    default:
      return "Não foi possível concluir. Verifique a internet e tente de novo.";
  }
}

module.exports = { traduzirErroBanco, nomeDaRegra };
