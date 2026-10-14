import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cliente.dart';
import '../models/laudo_manutencao.dart';
import '../models/locacao.dart';
import '../models/usuario.dart';
import '../models/veiculo.dart';

/// Camada única de acesso ao banco de dados: fala com o MESMO projeto
/// Supabase que o app desktop do Caio usa (rhdmiqcfksekmrtgnjgo), nas
/// mesmas tabelas (usuarios, clientes, veiculos, locacoes) — assim os
/// dois apps compartilham dados de verdade.
///
/// A conexão em si (URL + chave) é configurada uma única vez, em
/// main.dart, através de `Supabase.initialize(...)`. Aqui a gente só
/// pega o client já pronto com `Supabase.instance.client` — nunca
/// chame `createClient` aqui, isso é sintaxe JavaScript (do desktop),
/// não existe em Dart.
///
/// A lógica aqui replica exatamente o que está em
/// `royale-cars-desktop/src/main/index.js` (os handlers do Electron),
/// só que em Dart: mesmo esquema multi-tenant por `id_empresa`, mesma
/// forma de logar (e-mail OU username + senha com hash bcrypt).
class SupabaseService {
  SupabaseService._interno();
  static final SupabaseService instance = SupabaseService._interno();

  SupabaseClient get _db => Supabase.instance.client;

  // ---------------------------------------------------------------------
  // AUTENTICAÇÃO
  // ---------------------------------------------------------------------

  /// Faz login por e-mail OU username, comparando a senha com o hash
  /// bcrypt salvo no banco (mesma lógica do desktop). Se a senha ainda
  /// estiver em texto puro (contas antigas), migra pra hash automaticamente.
  Future<Usuario> login(String loginOuEmail, String senha) async {
    final resposta = await _db
        .from('usuarios')
        .select()
        .or('email.eq.$loginOuEmail,username.eq.$loginOuEmail');

    // 🌟 LOG TEMPORÁRIO DE DIAGNÓSTICO — remover depois que o login
    // estiver funcionando. Aparece no terminal onde você rodou
    // `flutter run`.
    debugPrint('[LOGIN] linhas encontradas para "$loginOuEmail": ${resposta.length}');

    if (resposta.isEmpty) {
      debugPrint('[LOGIN] nenhuma linha encontrada — verifique se o e-mail/username bate exatamente com o do Supabase.');
      throw Exception('Usuário ou senha incorretos.');
    }

    final dados = resposta.first;
    final senhaSalva = dados['senha'] as String;
    debugPrint('[LOGIN] usuário encontrado: id=${dados['id']}, id_empresa=${dados['id_empresa']}');
    debugPrint('[LOGIN] prefixo do hash salvo: ${senhaSalva.substring(0, senhaSalva.length > 7 ? 7 : senhaSalva.length)}');

    final jaEmHash = senhaSalva.startsWith('\$2a\$') ||
        senhaSalva.startsWith('\$2b\$') ||
        senhaSalva.startsWith('\$2y\$');

    bool senhaCorreta;
    if (jaEmHash) {
      senhaCorreta = BCrypt.checkpw(senha, senhaSalva);
      debugPrint('[LOGIN] comparação bcrypt (hash existente) => $senhaCorreta');
    } else {
      senhaCorreta = senha == senhaSalva;
      debugPrint('[LOGIN] senha salva NÃO está em hash — comparação em texto puro => $senhaCorreta');
      if (senhaCorreta) {
        final novoHash = BCrypt.hashpw(senha, BCrypt.gensalt());
        await _db.from('usuarios').update({'senha': novoHash}).eq('id', dados['id']);
        dados['senha'] = novoHash;
      }
    }

    if (!senhaCorreta) {
      throw Exception('Usuário ou senha incorretos.');
    }

    return Usuario.fromMap(dados);
  }

  /// Cria uma nova conta/empresa (mesmo fluxo "Proprietário" do desktop):
  /// insere o usuário, descobre o id gerado, e usa esse mesmo id como
  /// id_empresa (a empresa "é" o usuário que a criou).
  Future<void> criarConta({
    required String username,
    required String email,
    required String senha,
  }) async {
    final existente = await _db
        .from('usuarios')
        .select('id')
        .or('email.eq.$email,username.eq.$username');

    if (existente.isNotEmpty) {
      throw Exception('Este e-mail ou nome de usuário já está sendo utilizado.');
    }

    final senhaHash = BCrypt.hashpw(senha, BCrypt.gensalt());

    final inserido = await _db
        .from('usuarios')
        .insert({'username': username, 'email': email, 'senha': senhaHash})
        .select('id')
        .single();

    final idGerado = inserido['id'];
    await _db.from('usuarios').update({'id_empresa': idGerado}).eq('id', idGerado);
  }

  Future<void> trocarSenha({
    required Usuario usuarioLogado,
    required String senhaAtual,
    required String novaSenha,
  }) async {
    final jaEmHash = usuarioLogado.senha.startsWith('\$2a\$') ||
        usuarioLogado.senha.startsWith('\$2b\$') ||
        usuarioLogado.senha.startsWith('\$2y\$');
    final senhaAtualCorreta = jaEmHash
        ? BCrypt.checkpw(senhaAtual, usuarioLogado.senha)
        : senhaAtual == usuarioLogado.senha;

    if (!senhaAtualCorreta) {
      throw Exception('A senha atual informada está incorreta.');
    }

    final novoHash = BCrypt.hashpw(novaSenha, BCrypt.gensalt());
    await _db.from('usuarios').update({'senha': novoHash}).eq('id', usuarioLogado.id as Object);
  }

  // ---------------------------------------------------------------------
  // FROTA (veículos)
  // ---------------------------------------------------------------------

  Future<List<Veiculo>> buscarFrota(int idEmpresa) async {
    final dados = await _db
        .from('veiculos')
        .select()
        .eq('id_empresa', idEmpresa)
        .eq('ativo', true)
        .order('id');
    return dados.map((m) => Veiculo.fromMap(m)).toList();
  }

  Future<List<Veiculo>> buscarFrotaArquivada(int idEmpresa) async {
    final dados = await _db
        .from('veiculos')
        .select()
        .eq('id_empresa', idEmpresa)
        .eq('ativo', false)
        .order('id');
    return dados.map((m) => Veiculo.fromMap(m)).toList();
  }

  Future<void> salvarVeiculo(Veiculo veiculo, int idEmpresa) async {
    if (veiculo.id != null) {
      await _db.from('veiculos').update(veiculo.toMap()).eq('id', veiculo.id as Object);
    } else {
      await _db.from('veiculos').insert({...veiculo.toMap(), 'id_empresa': idEmpresa});
    }
  }

  Future<void> arquivarVeiculo(int idVeiculo) async {
    final ativas = await _db
        .from('locacoes')
        .select('id')
        .eq('id_veiculo', idVeiculo)
        .eq('status', Locacao.statusAtivo);
    if (ativas.isNotEmpty) {
      throw Exception(
          'Este veículo está com uma locação ativa. Finalize a locação antes de arquivá-lo.');
    }
    await _db.from('veiculos').update({'ativo': false}).eq('id', idVeiculo);
  }

  Future<void> reativarVeiculo(int idVeiculo) async {
    await _db.from('veiculos').update({'ativo': true}).eq('id', idVeiculo);
  }

  // ---------------------------------------------------------------------
  // CLIENTES
  // ---------------------------------------------------------------------

  Future<List<Cliente>> buscarClientes(int idEmpresa) async {
    final dados = await _db
        .from('clientes')
        .select()
        .eq('id_empresa', idEmpresa)
        .eq('ativo', true)
        .order('nome');
    return dados.map((m) => Cliente.fromMap(m)).toList();
  }

  Future<List<Cliente>> buscarClientesArquivados(int idEmpresa) async {
    final dados = await _db
        .from('clientes')
        .select()
        .eq('id_empresa', idEmpresa)
        .eq('ativo', false)
        .order('nome');
    return dados.map((m) => Cliente.fromMap(m)).toList();
  }

  Future<void> salvarCliente(Cliente cliente, int idEmpresa) async {
    if (cliente.id != null) {
      await _db.from('clientes').update(cliente.toMap()).eq('id', cliente.id as Object);
    } else {
      await _db.from('clientes').insert({...cliente.toMap(), 'id_empresa': idEmpresa});
    }
  }

  Future<void> arquivarCliente(int idCliente) async {
    final ativas = await _db
        .from('locacoes')
        .select('id')
        .eq('id_cliente', idCliente)
        .eq('status', Locacao.statusAtivo);
    if (ativas.isNotEmpty) {
      throw Exception(
          'Este cliente possui uma locação ativa. Finalize a locação antes de arquivá-lo.');
    }
    await _db.from('clientes').update({'ativo': false}).eq('id', idCliente);
  }

  Future<void> reativarCliente(int idCliente) async {
    await _db.from('clientes').update({'ativo': true}).eq('id', idCliente);
  }

  // ---------------------------------------------------------------------
  // LOCAÇÕES
  // ---------------------------------------------------------------------

  static const _selectComJoin =
      'id, id_empresa, id_cliente, id_veiculo, data_inicio, data_fim, valor_total, status, km_saida, km_retorno, assinatura_base64, clientes(nome), veiculos(modelo, placa)';

  Future<List<Locacao>> buscarLocacoesAtivas(int idEmpresa) async {
    final dados = await _db
        .from('locacoes')
        .select(_selectComJoin)
        .eq('status', Locacao.statusAtivo)
        .eq('id_empresa', idEmpresa)
        .order('id', ascending: false);
    return dados.map((m) => Locacao.fromMap(m)).toList();
  }

  Future<List<Locacao>> buscarLocacoesHistorico(int idEmpresa) async {
    final dados = await _db
        .from('locacoes')
        .select(_selectComJoin)
        .eq('status', Locacao.statusConcluido)
        .eq('id_empresa', idEmpresa)
        .order('data_fim', ascending: false);
    return dados.map((m) => Locacao.fromMap(m)).toList();
  }

  /// Registra a locação, confirma que o veículo ainda está disponível
  /// (evita corrida entre dois usuários alugando o mesmo carro) e marca
  /// o veículo como Alugado — igual ao desktop.
  Future<void> salvarLocacao(Locacao locacao, int idEmpresa) async {
    final veiculoAtual = await _db
        .from('veiculos')
        .select('status')
        .eq('id', locacao.idVeiculo)
        .single();

    if (veiculoAtual['status'] != Veiculo.statusDisponivel) {
      throw Exception(
          'Este veículo não está mais disponível (status atual: ${veiculoAtual['status']}). Atualize a lista e escolha outro.');
    }

    await _db.from('locacoes').insert({...locacao.toMap(), 'id_empresa': idEmpresa});
    await _db.from('veiculos').update({'status': Veiculo.statusAlugado}).eq('id', locacao.idVeiculo);
  }

  /// Finaliza a locação (devolução): marca como Concluído, libera o
  /// veículo e — se informado — atualiza a quilometragem do veículo e
  /// guarda a assinatura digital do cliente no contrato.
  Future<void> finalizarLocacao({
    required int idLocacao,
    required int idVeiculo,
    int? kmRetorno,
    String? assinaturaBase64,
    double? novoValorTotal,
  }) async {
    final atualizacaoLocacao = <String, dynamic>{'status': Locacao.statusConcluido};
    if (kmRetorno != null) atualizacaoLocacao['km_retorno'] = kmRetorno;
    if (novoValorTotal != null) atualizacaoLocacao['valor_total'] = novoValorTotal;
    if (assinaturaBase64 != null) {
      atualizacaoLocacao['assinatura_base64'] = assinaturaBase64;
      atualizacaoLocacao['contrato_gerado_em'] = DateTime.now().toIso8601String();
    }

    await _db.from('locacoes').update(atualizacaoLocacao).eq('id', idLocacao);

    final atualizacaoVeiculo = <String, dynamic>{'status': Veiculo.statusDisponivel};
    if (kmRetorno != null) atualizacaoVeiculo['quilometragem'] = kmRetorno;
    await _db.from('veiculos').update(atualizacaoVeiculo).eq('id', idVeiculo);
  }

  // ---------------------------------------------------------------------
  // MANUTENÇÃO (laudos) — exclusivo do app Flutter
  // ---------------------------------------------------------------------

  Future<List<LaudoManutencao>> buscarLaudos(int idEmpresa) async {
    final dados = await _db
        .from('laudos_manutencao')
        .select()
        .eq('id_empresa', idEmpresa)
        .order('data_registro', ascending: false);
    return dados.map((m) => LaudoManutencao.fromMap(m)).toList();
  }

  /// Salva o laudo e marca o veículo como "Em Manutenção" — assim o
  /// status do veículo fica consistente com o mesmo campo que o
  /// desktop usa (veiculos.status).
  Future<void> salvarLaudo(LaudoManutencao laudo, int idEmpresa) async {
    await _db.from('laudos_manutencao').insert({...laudo.toMap(), 'id_empresa': idEmpresa});
    await _db
        .from('veiculos')
        .update({'status': Veiculo.statusManutencao}).eq('id', laudo.idVeiculo);
  }

  /// Marca a manutenção como concluída, liberando o veículo de novo.
  Future<void> concluirManutencao(int idVeiculo) async {
    await _db.from('veiculos').update({'status': Veiculo.statusDisponivel}).eq('id', idVeiculo);
  }

  // ---------------------------------------------------------------------
  // FINANÇAS
  // ---------------------------------------------------------------------

  /// Réplica do cálculo financeiro do desktop: faturamento do mês
  /// atual x anterior, variação percentual, ticket médio e recebimento
  /// projetado das locações ainda ativas.
  Future<Map<String, dynamic>> buscarDadosFinanceiros(int idEmpresa) async {
    final todasLocacoes = await _db
        .from('locacoes')
        .select('id, data_fim, valor_total, status, clientes(nome), veiculos(modelo, placa)')
        .eq('id_empresa', idEmpresa)
        .order('data_fim', ascending: false);

    final agora = DateTime.now();
    final mesAtual = agora.month;
    final anoAtual = agora.year;
    final mesPassadoData = DateTime(anoAtual, mesAtual - 1, 1);

    double faturamentoMesAtual = 0;
    double faturamentoMesAnterior = 0;
    double recebimentoProjetado = 0;
    int totalConcluidos = 0;
    final fluxoCaixa = <Map<String, dynamic>>[];

    for (final loc in todasLocacoes) {
      final valor = (loc['valor_total'] is num)
          ? (loc['valor_total'] as num).toDouble()
          : double.tryParse('${loc['valor_total']}') ?? 0;

      if (loc['status'] == Locacao.statusConcluido) {
        totalConcluidos++;
        fluxoCaixa.add(loc);
        final dataFim = DateTime.tryParse('${loc['data_fim']}');
        if (dataFim != null) {
          if (dataFim.month == mesAtual && dataFim.year == anoAtual) {
            faturamentoMesAtual += valor;
          } else if (dataFim.month == mesPassadoData.month && dataFim.year == mesPassadoData.year) {
            faturamentoMesAnterior += valor;
          }
        }
      } else if (loc['status'] == Locacao.statusAtivo) {
        recebimentoProjetado += valor;
      }
    }

    double variacaoPercentual = 0;
    if (faturamentoMesAnterior > 0) {
      variacaoPercentual =
          ((faturamentoMesAtual - faturamentoMesAnterior) / faturamentoMesAnterior) * 100;
    } else if (faturamentoMesAtual > 0) {
      variacaoPercentual = 100;
    }

    final ticketMedio = totalConcluidos > 0 ? (faturamentoMesAtual / totalConcluidos) : 0.0;

    return {
      'faturamentoTotal': faturamentoMesAtual,
      'recebimentoProjetado': recebimentoProjetado,
      'ticketMedio': ticketMedio,
      'variacaoPercentual': double.parse(variacaoPercentual.toStringAsFixed(1)),
      'fluxoCaixa': fluxoCaixa,
    };
  }
}