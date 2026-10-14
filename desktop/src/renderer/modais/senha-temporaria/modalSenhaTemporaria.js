// =====================================================================
//  Janela da senha temporária
// ---------------------------------------------------------------------
//  Abre depois de cadastrar alguém ou de redefinir a senha de alguém.
//  Ela pede a senha ao processo principal UMA vez: ele entrega e apaga.
//  Por isso, fechou a janela, a senha não volta mais.
// =====================================================================

document.addEventListener('DOMContentLoaded', async () => {
  const textoPessoa = document.getElementById('texto-pessoa');
  const senhaTexto = document.getElementById('senha-texto');
  const btnCopiar = document.getElementById('btn-copiar');

  const dados = await window.apiAcesso.pedirSenhaTemporaria();

  if (dados) {
    // textContent: nome e senha entram como texto, nunca como HTML
    textoPessoa.textContent = dados.email
      ? `${dados.nome} foi cadastrado(a). Login: ${dados.email}`
      : `Nova senha de ${dados.nome}:`;
    senhaTexto.textContent = dados.senha;
  } else {
    textoPessoa.textContent = 'A senha já foi mostrada e não está mais disponível.';
    btnCopiar.disabled = true;
  }

  btnCopiar.addEventListener('click', () => {
    window.apiAcesso.copiarTexto(senhaTexto.textContent);
    btnCopiar.classList.add('copiado');
    btnCopiar.innerHTML = '<i class="ri-check-line"></i> Copiado';
  });

  document.getElementById('btn-entendi').addEventListener('click', () => {
    window.apiAcesso.fecharModalSenhaTemporaria();
  });
});
