// =====================================================================
//  Conexão com o banco (Supabase)
// ---------------------------------------------------------------------
//  Fica num arquivo só dela para que todo o processo principal use a
//  MESMA conexão. Quem precisar do banco faz:
//      const supabase = require("./supabase");
//
//  A chave "publishable" pode ficar no código: sozinha ela não dá
//  acesso a nada. Quem decide o que cada pessoa vê é o banco (RLS),
//  olhando o login de quem está usando o app.
// =====================================================================

const { createClient } = require("@supabase/supabase-js");

const SUPABASE_URL = "https://saggupyjutibjruajwms.supabase.co";
const SUPABASE_KEY = "sb_publishable_IfgXLkrumbCFJ_UswbOwyQ_JNaMKoDN";

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY, {
  auth: {
    // O login fica guardado só na memória enquanto o app está aberto.
    // Fechou o app, precisa entrar de novo.
    persistSession: false,
    // Renova o "crachá" (token) sozinho antes de ele vencer.
    autoRefreshToken: true,
  },
});

module.exports = supabase;
