const { createClient } = require("@supabase/supabase-js");

const SUPABASE_URL = "https://saggupyjutibjruajwms.supabase.co";
const SUPABASE_KEY = "sb_publishable_IfgXLkrumbCFJ_UswbOwyQ_JNaMKoDN";

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY, {
  auth: {
    persistSession: false,
    autoRefreshToken: true,
  },
});

module.exports = supabase;
