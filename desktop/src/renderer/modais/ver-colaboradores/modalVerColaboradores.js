document.addEventListener('DOMContentLoaded', async () => {
  const lista = document.getElementById('lista-colaboradores');

  let grupo = null;
  try {
    grupo = JSON.parse(localStorage.getItem('grupoParaVerColaboradores'));
    localStorage.removeItem('grupoParaVerColaboradores');
  } catch (e) {
    grupo = null;
  }

  function fechar() {
    window.apiAcesso.fecharModalVerColaboradores();
  }
  document.getElementById('btn-fechar').addEventListener('click', fechar);
  document.getElementById('btn-fechar-topo').addEventListener('click', fechar);

  if (!grupo) {
    lista.innerHTML = '<div class="vazio">Grupo não encontrado.</div>';
    return;
  }

  document.getElementById('titulo-modal').textContent = 'Grupo: ' + grupo.nome;

  async function carregar() {
    const [colaboradores, grupos] = await Promise.all([
      window.apiAcesso.pedirColaboradoresDoGrupo(grupo.id),
      window.apiAcesso.pedirGruposPermissao()
    ]);

    lista.innerHTML = '';

    if (!colaboradores.length) {
      lista.innerHTML = '<div class="vazio">Nenhum colaborador neste grupo.</div>';
      return;
    }

    colaboradores.forEach(c => {
      const item = document.createElement('div');
      item.className = 'item-colab';

      const info = document.createElement('div');
      info.className = 'info';
      const nomeEl = document.createElement('strong');
      nomeEl.textContent = (c.nome || c.username) + (c.ativo === false ? ' (arquivado)' : '');
      const userEl = document.createElement('span');
      userEl.textContent = '@' + c.username;
      info.appendChild(nomeEl);
      info.appendChild(userEl);

      const bloco = document.createElement('div');
      const rotulo = document.createElement('span');
      rotulo.className = 'rotulo-mover';
      rotulo.textContent = 'Mover para:';
      const select = document.createElement('select');
      grupos.forEach(g => {
        const opt = document.createElement('option');
        opt.value = g.id;
        opt.textContent = g.nome;
        if (String(g.id) === String(grupo.id)) opt.selected = true;
        select.appendChild(opt);
      });

      select.addEventListener('change', async () => {
        select.disabled = true;
        try {
          const resposta = await window.apiAcesso.moverColaboradorDeGrupo({
            idColaborador: c.id,
            idNovoGrupo: select.value
          });
          // Dando certo ou não, recarrega: quem saiu do grupo some da lista.
          if (resposta && resposta.sucesso) {
            await carregar();
          } else {
            select.value = grupo.id;
            select.disabled = false;
          }
        } catch (erro) {
          console.error('Erro ao mover colaborador:', erro);
          select.value = grupo.id;
          select.disabled = false;
        }
      });

      bloco.appendChild(rotulo);
      bloco.appendChild(select);
      item.appendChild(info);
      item.appendChild(bloco);
      lista.appendChild(item);
    });
  }

  await carregar();
});
