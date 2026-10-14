import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/splash_page.dart';
import 'theme/app_theme.dart';

// 🌟 MESMO projeto Supabase que o app desktop do Caio já usa — os dois
// apps compartilham o banco de dados de verdade (tabelas usuarios,
// clientes, veiculos, locacoes). Nunca coloque a chave "service_role"
// aqui, só a "publishable"/"anon" — essa é segura de embutir no app.
const _supabaseUrl = 'https://rhdmiqcfksekmrtgnjgo.supabase.co';
const _supabasePublishableKey = 'sb_publishable_CJtd4q_aCbOMKkxQ45w5mg_mZ_Rf1ys';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );
  runApp(const RoyaleCarsApp());
}

class RoyaleCarsApp extends StatelessWidget {
  const RoyaleCarsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ROYALE-CARS',
      theme: AppTheme.lightTheme,
      home: const SplashPage(),
    );
  }
}
