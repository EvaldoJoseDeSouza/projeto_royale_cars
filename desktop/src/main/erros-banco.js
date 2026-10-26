
function nomeDaRegra(erro) {
  const texto = `${erro.message || ""} ${erro.details || ""}`;
  const achado = texto.match(/constraint "([^"]+)"/);
  return achado ? achado[1] : "";
}


function traduzirErroBanco(erro, mensagens = {}) {
  if (!erro) return "";

  const regra = nomeDaRegra(erro);
  if (regra && mensagens[regra]) return mensagens[regra];

  switch (erro.code) {
    case "P0001":
      return erro.message; 
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
