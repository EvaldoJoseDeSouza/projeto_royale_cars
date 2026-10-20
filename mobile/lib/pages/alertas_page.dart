import 'package:flutter/material.dart';
import '../dependencies.dart';
import '../models/painel.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../utils/permissoes.dart';
import '../widgets/animated_golden_title.dart';
import '../widgets/royale_footer.dart';
import 'cadastro_cliente_page.dart';
import 'locacao_detalhes_page.dart';
import 'manutencao_page.dart';

/// Os alertas automáticos, os MESMOS da web e do desktop (visão vw_alertas):
///   atraso             aluguel que passou da data prevista
///   devolucao_proxima  devolução hoje ou nos próximos 2 dias
///   manutencao         carro na oficina (avisa se a previsão venceu)
///   cnh                cliente com CNH vencida ou vencendo em 30 dias
///   login_suspeito     3+ senhas erradas do mesmo e-mail em 24 h (só o chefe vê)
class AlertasPage extends StatefulWidget {
  const AlertasPage({super.key});

  /// Cor e ícone de cada tipo (as mesmas cores das etiquetas da web)
  static (Color, IconData) visual(String tipo) => switch (tipo) {
        'atraso' => (RoyaleColors.statusAlugado, Icons.timer_off),
        'devolucao_proxima' => (RoyaleColors.azulMarinho, Icons.event),
        'manutencao' => (RoyaleColors.statusManutencao, Icons.build),
        'cnh' => (RoyaleColors.statusManutencao, Icons.badge),
        _ => (RoyaleColors.statusAlugado, Icons.security),
      };

  /// Toca num alerta → abre a tela certa (se a pessoa tiver permissão).
  /// Devolve true se abriu alguma tela (para quem chamou recarregar depois).
  static Future<bool> abrir(BuildContext context, Alerta alerta) async {
    void avisar(String texto) =>
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

    switch (alerta.tipo) {
      case 'atraso':
      case 'devolucao_proxima':
        if (!authController.pode(Permissao.locacoesVer) || alerta.referenciaId == null) return false;
        try {
          final locacao = await SupabaseService.instance.buscarLocacao(alerta.referenciaId!);
          if (!context.mounted) return false;
          await Navigator.push(context, MaterialPageRoute(builder: (context) => LocacaoDetalhesPage(locacao: locacao)));
          return true;
        } catch (_) {
          if (context.mounted) avisar('Não foi possível abrir este aluguel agora.');
          return false;
        }

      case 'manutencao':
        if (!authController.pode(Permissao.manutencoes)) return false;
        await Navigator.push(context, MaterialPageRoute(builder: (context) => const ManutencaoPage()));
        return true;

      case 'cnh':
        if (!authController.pode(Permissao.clientesGerenciar)) return false;
        final cliente = clienteController.clientes.where((c) => c.id == alerta.referenciaId).firstOrNull;
        if (cliente == null) return false;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CadastroClientePage(clienteParaEditar: cliente)),
        );
        return true;

      default: // login_suspeito: a lista de tentativas fica só na web
        avisar('Veja os detalhes em Tentativas de login, na Administração da web.');
        return false;
    }
  }

  @override
  State<AlertasPage> createState() => _AlertasPageState();
}

class _AlertasPageState extends State<AlertasPage> {
  late Future<List<Alerta>> _alertas = SupabaseService.instance.buscarAlertas();

  Future<void> _recarregar() async {
    final novo = SupabaseService.instance.buscarAlertas();
    setState(() => _alertas = novo);
    await novo;
  }

  Future<void> _abrir(Alerta alerta) async {
    if (await AlertasPage.abrir(context, alerta)) _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AnimatedGoldenTitle('Alertas', fontSize: 24)),
      body: FutureBuilder<List<Alerta>>(
        future: _alertas,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: RoyaleColors.azulMarinho));
          }

          final alertas = snapshot.data ?? [];
          final mensagem = snapshot.hasError
              ? 'Não foi possível carregar os alertas. Puxe para baixo para tentar de novo.'
              : 'Nenhum alerta. Está tudo em dia! 🎉';

          // Agrupa por tipo, na ordem de Alerta.nomes
          final grupos = <String, List<Alerta>>{};
          for (final tipo in Alerta.nomes.keys) {
            final doTipo = alertas.where((a) => a.tipo == tipo).toList();
            if (doTipo.isNotEmpty) grupos[tipo] = doTipo;
          }

          return RefreshIndicator(
            onRefresh: _recarregar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                if (grupos.isEmpty) ...[
                  const SizedBox(height: 80),
                  Center(child: Text(mensagem, style: const TextStyle(color: Colors.grey))),
                ],
                for (final grupo in grupos.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                    child: Text('${Alerta.nomes[grupo.key]} (${grupo.value.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: RoyaleColors.azulMarinho)),
                  ),
                  for (final alerta in grupo.value)
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(AlertasPage.visual(alerta.tipo).$2, color: AlertasPage.visual(alerta.tipo).$1),
                        title: Text(alerta.titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(alerta.detalhe),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _abrir(alerta),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const RoyaleFooter(),
    );
  }
}
