const sessao = {
  usuario: null,
};

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
