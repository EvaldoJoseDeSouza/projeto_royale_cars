import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/splash_page.dart';
import 'theme/app_theme.dart';

// O MESMO projeto Supabase da web e do desktop ("royale-cars-final"):
// as três plataformas usam o mesmo banco, com as mesmas regras.
// Aqui fica só a chave PÚBLICA ("publishable"), que pode ir no app: quem
// protege os dados são as regras do banco (RLS). Nunca coloque aqui a
// chave de serviço ("secret"/"service_role").
const _supabaseUrl = 'https://saggupyjutibjruajwms.supabase.co';
const _supabasePublishableKey = 'sb_publishable_IfgXLkrumbCFJ_UswbOwyQ_JNaMKoDN';

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
