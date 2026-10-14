// =====================================================================
//  Sessão: quem está logado agora
// ---------------------------------------------------------------------
//  Guarda os dados que a função iniciar_sessao do banco devolve:
//    { id, nome, email, cargo, trocar_senha, permissoes: [...] }
//
//  É um objeto compartilhado: qualquer arquivo que fizer
//  require("./sessao") enxerga o mesmo usuário logado.
// =====================================================================

const sessao = {
  usuario: null,
};

// O chefe pode tudo. Os outros só o que estiver na lista de permissões.
// As chaves são as 13 do banco unificado (ex.: "clientes_ver").
function temPermissao(chave) {
  const usuario = sessao.usuario;
  if (!usuario) return false;
  if (usuario.cargo === "chefe") return true;
  return Array.isArray(usuario.permissoes) && usuario.permissoes.includes(chave);
}

function limparSessao() {
  sessao.usuario = null;
}

module.exports = { sessao, temPermissao, limparSessao };
