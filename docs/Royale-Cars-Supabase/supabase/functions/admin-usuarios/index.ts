// =====================================================================
// ROYALE CARS - Edge Function "admin-usuarios"
// ---------------------------------------------------------------------
// Ações do Painel Administrativo que precisam da chave de serviço
// (service_role), que NUNCA pode ficar dentro do app web, desktop ou
// celular. Só o chefe consegue chamar.
//
// Publicar:  supabase functions deploy admin-usuarios
//
// Chamar (igual nas 3 plataformas, com o token do chefe logado):
//   Electron/JS: supabase.functions.invoke('admin-usuarios', { body: { acao: 'criar', ... } })
//   Flutter:     supabase.functions.invoke('admin-usuarios', body: {'acao': 'criar', ...})
//   PHP:         POST {SUPABASE_URL}/functions/v1/admin-usuarios  (Authorization: Bearer <token do chefe>)
//
// Ações:
//   { acao: 'criar', nome, email, cargo: 'gerente'|'funcionario', permissoes: [...] }
//        → { usuario_id, senha_temporaria }
//   { acao: 'redefinir_senha', usuario_id }      → { senha_temporaria }
//   { acao: 'ativar' | 'desativar', usuario_id } → { ok: true }
//   { acao: 'alterar_email', usuario_id, email } → { ok: true }
// =====================================================================

import { createClient } from 'jsr:@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const PERMISSOES = [
  'clientes_ver', 'clientes_gerenciar', 'clientes_arquivar',
  'veiculos_ver', 'veiculos_gerenciar', 'veiculos_arquivar',
  'locacoes_ver', 'locacoes_gerenciar', 'locacoes_cancelar',
  'manutencoes', 'financeiro', 'relatorios', 'relatorios_financeiros',
];

// Marcar uma permissão de ação liga as de "ver" que ela precisa
const DEPENDENCIAS: Record<string, string[]> = {
  clientes_gerenciar: ['clientes_ver'],
  clientes_arquivar: ['clientes_ver'],
  veiculos_gerenciar: ['veiculos_ver'],
  veiculos_arquivar: ['veiculos_ver'],
  locacoes_gerenciar: ['locacoes_ver', 'clientes_ver', 'veiculos_ver'],
  locacoes_cancelar: ['locacoes_ver'],
  manutencoes: ['veiculos_ver'],
  relatorios_financeiros: ['relatorios'],
};

function resposta(corpo: unknown, status = 200) {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

// Senha fácil de ditar, sem 0/O e 1/l/I. Ex.: "Kp7m-Qx3t"
function gerarSenha(): string {
  const letras = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ';
  const numeros = '23456789';
  const sorteia = (texto: string) => texto[crypto.getRandomValues(new Uint32Array(1))[0] % texto.length];
  const parte = () => sorteia(letras) + sorteia(letras) + sorteia(numeros) + sorteia(letras);

  return `${parte()}-${parte()}`;
}

function limparPermissoes(lista: unknown): string[] {
  const marcadas = Array.isArray(lista) ? lista.filter((p) => PERMISSOES.includes(String(p))).map(String) : [];
  const todas = new Set(marcadas);

  for (const p of marcadas) {
    for (const dependencia of DEPENDENCIAS[p] ?? []) {
      todas.add(dependencia);
    }
  }

  return [...todas];
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS });
  }

  const url = Deno.env.get('SUPABASE_URL')!;
  const chaveAnon = Deno.env.get('SUPABASE_ANON_KEY')!;
  const chaveServico = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  // Cliente "como o chefe": tudo que ele grava passa pelas regras e entra no histórico com o nome dele
  const comoChefe = createClient(url, chaveAnon, {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
  });

  const { data: ehChefe, error: erroChefe } = await comoChefe.rpc('eh_chefe');

  if (erroChefe || ehChefe !== true) {
    return resposta({ erro: 'Só o chefe pode fazer isso.' }, 403);
  }

  // Cliente administrador: só para mexer nas contas de login (Supabase Auth)
  const admin = createClient(url, chaveServico, { auth: { persistSession: false } });

  let corpo: Record<string, unknown>;

  try {
    corpo = await req.json();
  } catch {
    return resposta({ erro: 'Corpo da requisição inválido.' }, 400);
  }

  const usuarioId = String(corpo.usuario_id ?? '');

  // Nenhuma ação (fora "criar") pode mirar o chefe
  if (corpo.acao !== 'criar') {
    const { data: alvo } = await comoChefe.from('perfis').select('cargo').eq('id', usuarioId).maybeSingle();

    if (!alvo || alvo.cargo === 'chefe') {
      return resposta({ erro: 'Usuário não encontrado ou não pode ser alterado.' }, 400);
    }
  }

  switch (corpo.acao) {
    case 'criar': {
      const nome = String(corpo.nome ?? '').trim().replace(/\s+/g, ' ');
      const email = String(corpo.email ?? '').trim().toLowerCase();
      const cargo = String(corpo.cargo ?? '');
      const permissoes = limparPermissoes(corpo.permissoes);

      if (!/^\S+\s+\S+/.test(nome)) return resposta({ erro: 'Informe nome e sobrenome.' }, 400);
      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return resposta({ erro: 'Digite um e-mail válido.' }, 400);
      if (!['gerente', 'funcionario'].includes(cargo)) return resposta({ erro: 'Escolha o cargo.' }, 400);
      if (permissoes.length === 0) return resposta({ erro: 'Marque pelo menos uma permissão.' }, 400);

      const senha = gerarSenha();
      const { data: criado, error } = await admin.auth.admin.createUser({ email, password: senha, email_confirm: true });

      if (error || !criado.user) {
        return resposta({ erro: error?.message.includes('already') ? 'Já existe um usuário com este e-mail.' : 'Não foi possível criar o login.' }, 400);
      }

      const id = criado.user.id;
      const { error: erroPerfil } = await comoChefe.from('perfis').insert({ id, nome, email, cargo, ativo: true, trocar_senha: true });

      if (erroPerfil) {
        await admin.auth.admin.deleteUser(id); // desfaz o login se o perfil falhar
        return resposta({ erro: erroPerfil.message }, 400);
      }

      await comoChefe.from('usuario_permissoes').insert(permissoes.map((permissao) => ({ usuario_id: id, permissao })));

      return resposta({ usuario_id: id, senha_temporaria: senha });
    }

    case 'redefinir_senha': {
      const senha = gerarSenha();
      const { error } = await admin.auth.admin.updateUserById(usuarioId, { password: senha });

      if (error) return resposta({ erro: 'Não foi possível redefinir a senha.' }, 400);

      await comoChefe.rpc('marcar_senha_redefinida', { p_usuario_id: usuarioId });

      return resposta({ senha_temporaria: senha });
    }

    case 'ativar':
    case 'desativar': {
      const ativo = corpo.acao === 'ativar';
      const { error } = await comoChefe.from('perfis').update({ ativo }).eq('id', usuarioId);

      if (error) return resposta({ erro: error.message }, 400);

      // Também bloqueia o login no Supabase Auth (o RLS já corta o acesso aos dados na hora)
      await admin.auth.admin.updateUserById(usuarioId, { ban_duration: ativo ? 'none' : '876000h' });

      return resposta({ ok: true });
    }

    case 'alterar_email': {
      const email = String(corpo.email ?? '').trim().toLowerCase();

      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return resposta({ erro: 'Digite um e-mail válido.' }, 400);

      const { error } = await admin.auth.admin.updateUserById(usuarioId, { email, email_confirm: true });

      if (error) return resposta({ erro: 'Não foi possível alterar o e-mail (talvez já esteja em uso).' }, 400);

      await comoChefe.from('perfis').update({ email }).eq('id', usuarioId);

      return resposta({ ok: true });
    }

    default:
      return resposta({ erro: 'Ação desconhecida.' }, 400);
  }
});
