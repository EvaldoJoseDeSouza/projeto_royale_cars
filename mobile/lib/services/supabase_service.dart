import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cliente.dart';
import '../models/laudo_manutencao.dart';
import '../models/locacao.dart';
import '../models/usuario.dart';
import '../models/veiculo.dart';
import 'erros_banco.dart';

/// Camada única de acesso ao banco: fala com o MESMO projeto Supabase
/// que a web e o desktop usam. As regras (validação, permissões,
/// cálculo do aluguel, histórico) ficam no banco; o app cuida da tela.
///
/// A conexão em si (URL + chave pública) é configurada uma única vez,
/// em main.dart, através de `Supabase.initialize(...)`. Aqui a gente só
/// pega o client já pronto com `Supabase.instance.client`.
class SupabaseService {
  SupabaseService._interno();
  static final SupabaseService instance = SupabaseService._interno();

  SupabaseClient get _db => Supabase.instance.client;

  static const _plataforma = 'mobile';

  // ---------------------------------------------------------------------
  // LOGIN — o MESMO roteiro da web e do desktop:
  //   1. Pergunta ao banco se o e-mail está bloqueado (5 erros em 15 min)
  //   2. Tenta entrar pelo Supabase Auth (e-mail + senha)
  //   3. Registra a tentativa (certa ou errada) para o painel do chefe
  //   4. Pede ao banco o perfil e as permissões (iniciar_sessao)
  //      - se a pessoa estiver desativada, o banco recusa e saímos
  //
  // Quem confere a senha é o Supabase, não o app.
  // ---------------------------------------------------------------------

  Future<Usuario> entrar(String email, String senha) async {
    try {
      // 1. Bloqueado por muitas tentativas?
      final bloqueado = await _db.rpc('login_bloqueado', params: {'p_email': email});
      if (bloqueado == true) {
        throw Exception('Muitas tentativas erradas. Aguarde 15 minutos ou peça ao responsável para redefinir sua senha.');
      }

      // 2. Entrar pelo Supabase Auth
      try {
        await _db.auth.signInWithPassword(email: email, password: senha);
      } on AuthRetryableFetchException {
        rethrow; // sem internet: cai no "catch" de fora
      } on AuthException catch (erro) {
        // 3a. Errou: registra a tentativa
        await _registrarTentativa(email, false, erro.message);

        // Conta desativada pelo chefe: o Supabase responde "user_banned"
        if (erro.code == 'user_banned') {
          throw Exception('Seu acesso está desativado. Fale com o responsável pela locadora.');
        }

        // A mesma frase para e-mail que não existe e senha errada:
        // assim ninguém descobre quais e-mails estão cadastrados.
        throw Exception('E-mail ou senha incorretos.');
      }

      // 3b. Acertou
      await _registrarTentativa(email, true, null);

      // 4. Perfil e permissões
      return await carregarSessao();
    } catch (erro) {
      throw Exception(traduzirErroBanco(erro));
    }
  }

  /// Pede ao banco o perfil e as permissões de quem está logado.
  /// Usada no login e quando o app abre com a sessão já salva no aparelho.
  /// Se a pessoa foi desativada, o banco recusa: saímos e avisamos.
  Future<Usuario> carregarSessao() async {
    try {
      final dados = await _db.rpc('iniciar_sessao', params: {'p_plataforma': _plataforma});
      return Usuario.fromSessao(Map<String, dynamic>.from(dados as Map));
    } on PostgrestException catch (erro) {
      // O banco recusou (desativado, sem perfil, sessão vencida): sai da conta
      await sair();
      throw Exception(erro.code == 'P0001' ? erro.message : 'Sua sessão terminou. Entre novamente.');
    } catch (erro) {
      // Sem internet: NÃO sai da conta (a sessão continua salva para a próxima vez)
      throw Exception(mensagemSemConexao);
    }
  }

  /// Existe uma sessão guardada no aparelho (de um login anterior)?
  bool get temSessaoSalva => _db.auth.currentSession != null;

  /// Grava a tentativa no banco. Se falhar, só avisa no terminal:
  /// não pode impedir a pessoa de entrar por causa do registro.
  Future<void> _registrarTentativa(String email, bool sucesso, String? motivo) async {
    try {
      await _db.rpc('registrar_tentativa_login', params: {
        'p_email': email,
        'p_sucesso': sucesso,
        'p_motivo': motivo,
        'p_plataforma': _plataforma,
      });
    } catch (erro) {
      debugPrint('[LOGIN] Erro ao registrar tentativa: $erro');
    }
  }

  Future<void> sair() async {
    try {
      await _db.auth.signOut();
    } catch (erro) {
      // Sem internet, o signOut pode falhar no servidor, mas a sessão
      // guardada no aparelho é apagada do mesmo jeito.
      debugPrint('[SAIR] $erro');
    }
  }

  // ---------------------------------------------------------------------
  // SENHA
  // ---------------------------------------------------------------------

  /// Troca normal: confere a senha atual tentando entrar com ela
  /// (o Supabase não tem outro jeito de conferir) e grava a nova.
  Future<void> trocarSenha({
    required String email,
    required String senhaAtual,
    required String novaSenha,
  }) async {
    try {
      await _db.auth.signInWithPassword(email: email, password: senhaAtual);
    } on AuthRetryableFetchException {
      throw Exception(mensagemSemConexao);
    } on AuthException {
      throw Exception('A senha atual informada está incorreta.');
    }

    await gravarNovaSenha(novaSenha);
  }

  /// Grava a senha nova no Supabase Auth e avisa o banco (tira a marca de
  /// "trocar senha" e grava no histórico). Usada pela troca normal e pela
  /// obrigatória (senha temporária).
  Future<void> gravarNovaSenha(String novaSenha) async {
    try {
      await _db.auth.updateUser(UserAttributes(password: novaSenha));
    } on AuthRetryableFetchException {
      throw Exception(mensagemSemConexao);
    } on AuthException catch (erro) {
      if (erro.code == 'same_password') {
        throw Exception('A nova senha precisa ser diferente da atual.');
      }
      if (erro.code == 'weak_password') {
        throw Exception(regraSenha);
      }
      throw Exception('Não foi possível trocar sua senha. Tente novamente.');
    }

    try {
      await _db.rpc('senha_trocada');
    } catch (erro) {
      // A senha já mudou. Se só a marca falhar, no próximo login ele pede de novo.
      debugPrint('[SENHA] Erro ao avisar senha_trocada: $erro');
    }
  }

  /// Mesma regra de senha das 3 plataformas: 8+ caracteres, com letra e número.
  static const regraSenha = 'A senha precisa ter pelo menos 8 caracteres, com letras e números.';

  static bool senhaForte(String senha) =>
      senha.length >= 8 && RegExp(r'[A-Za-z]').hasMatch(senha) && RegExp(r'\d').hasMatch(senha);

  // ---------------------------------------------------------------------
  // FROTA (veículos)
  // ---------------------------------------------------------------------

  Future<List<Veiculo>> buscarFrota() async {
    final dados = await _db
        .from('veiculos')
        .select()
        .eq('ativo', true)
        .order('id');
    return dados.map((m) => Veiculo.fromMap(m)).toList();
  }

  Future<List<Veiculo>> buscarFrotaArquivada() async {
    final dados = await _db
        .from('veiculos')
        .select()
        .eq('ativo', false)
        .order('id');
    return dados.map((m) => Veiculo.fromMap(m)).toList();
  }

  Future<void> salvarVeiculo(Veiculo veiculo) async {
    if (veiculo.id != null) {
      await _db.from('veiculos').update(veiculo.toMap()).eq('id', veiculo.id as Object);
    } else {
      await _db.from('veiculos').insert(veiculo.toMap());
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
  // CLIENTES — as mesmas regras da web e do desktop:
  //  - A TELA ajuda quem digita (máscaras) e confere o simples.
  //  - O BANCO é o juiz final: dígitos do CPF e da CNH, DDD do telefone,
  //    e-mail, duplicados e se dá para arquivar (não deixa arquivar quem
  //    tem aluguel em andamento).
  //  - Nada é apagado: "arquivar" só esconde o cliente das listas.
  // ---------------------------------------------------------------------

  /// Frases para cada regra do banco (nomes em banco/01 e banco/02)
  static const _mensagensClientes = {
    'clientes_nome_check': 'Informe o nome completo (nome e sobrenome).',
    'clientes_cpf_check': 'CPF inválido. Confira os números digitados.',
    'clientes_cnh_check': 'Número de CNH inválido. Confira os 11 números.',
    'clientes_email_check': 'Digite um e-mail válido.',
    'clientes_telefone_check': 'Telefone inválido. Informe DDD + número, ex.: (19) 99999-9999.',
    'clientes_endereco_check': 'O endereço pode ter no máximo 200 caracteres.',
  };

  /// Para o aviso de duplicado: qual coluna cada regra UNIQUE protege
  static const _duplicadosClientes = {
    'clientes_cpf_key': ('cpf', 'Este CPF'),
    'clientes_cnh_key': ('cnh', 'Esta CNH'),
    'clientes_email_key': ('email', 'Este e-mail'),
  };

  Future<List<Cliente>> buscarClientes({bool arquivados = false}) async {
    final dados = await _db
        .from('clientes')
        .select(Cliente.colunas)
        .eq('arquivado', arquivados)
        .order('nome');
    return dados.map((m) => Cliente.fromMap(m)).toList();
  }

  /// Cadastra (sem id) ou edita (com id). Se o banco recusar, devolve
  /// uma frase em português dizendo o porquê.
  Future<void> salvarCliente(Cliente cliente) async {
    final dados = cliente.toMap();

    try {
      if (cliente.id != null) {
        await _db.from('clientes').update(dados).eq('id', cliente.id!);
      } else {
        await _db.from('clientes').insert(dados);
      }
    } on PostgrestException catch (erro) {
      debugPrint('[CLIENTES] Banco recusou: ${erro.code} ${erro.message}');
      final duplicado = _duplicadosClientes[nomeDaRegra(erro)];

      if (duplicado != null) {
        throw Exception(await _mensagemDeDuplicado(duplicado.$1, duplicado.$2, dados[duplicado.$1], cliente.id));
      }
      throw Exception(traduzirErroBanco(erro, _mensagensClientes));
    } catch (erro) {
      throw Exception(traduzirErroBanco(erro));
    }
  }

  /// CPF/CNH/e-mail repetido: diz DE QUEM é (igual à web e ao desktop).
  /// Se o dono estiver arquivado, sugere reativar em vez de cadastrar de novo.
  Future<String> _mensagemDeDuplicado(String coluna, String rotulo, Object? valor, int? idAtual) async {
    try {
      final dono = await _db
          .from('clientes')
          .select('nome, arquivado')
          .eq(coluna, valor ?? '')
          .neq('id', idAtual ?? 0)
          .maybeSingle();

      if (dono == null) return '$rotulo já está cadastrado.';
      if (dono['arquivado'] == true) {
        return '$rotulo pertence a ${dono['nome']}, que está arquivado. Reative esse cadastro em vez de criar outro.';
      }
      return '$rotulo já pertence ao cliente ${dono['nome']}.';
    } catch (_) {
      return '$rotulo já está cadastrado.';
    }
  }

  /// Arquiva ou reativa. Quem confere se o cliente tem aluguel em
  /// andamento é o banco: se tiver, ele recusa com uma frase pronta.
  Future<Cliente> mudarArquivadoCliente(int idCliente, bool arquivar) async {
    try {
      final dados = await _db
          .from('clientes')
          .update({'arquivado': arquivar})
          .eq('id', idCliente)
          .select(Cliente.colunas)
          .single();
      return Cliente.fromMap(dados);
    } catch (erro) {
      throw Exception(traduzirErroBanco(erro, _mensagensClientes));
    }
  }

  // ---------------------------------------------------------------------
  // LOCAÇÕES
  // ---------------------------------------------------------------------

  static const _selectComJoin =
      'id, id_cliente, id_veiculo, data_inicio, data_fim, valor_total, status, km_saida, km_retorno, assinatura_base64, clientes(nome), veiculos(modelo, placa)';

  Future<List<Locacao>> buscarLocacoesAtivas() async {
    final dados = await _db
        .from('locacoes')
        .select(_selectComJoin)
        .eq('status', Locacao.statusAtivo)
        .order('id', ascending: false);
    return dados.map((m) => Locacao.fromMap(m)).toList();
  }

  Future<List<Locacao>> buscarLocacoesHistorico() async {
    final dados = await _db
        .from('locacoes')
        .select(_selectComJoin)
        .eq('status', Locacao.statusConcluido)
        .order('data_fim', ascending: false);
    return dados.map((m) => Locacao.fromMap(m)).toList();
  }

  /// Registra a locação, confirma que o veículo ainda está disponível
  /// (evita corrida entre dois usuários alugando o mesmo carro) e marca
  /// o veículo como Alugado — igual ao desktop.
  Future<void> salvarLocacao(Locacao locacao) async {
    final veiculoAtual = await _db
        .from('veiculos')
        .select('status')
        .eq('id', locacao.idVeiculo)
        .single();

    if (veiculoAtual['status'] != Veiculo.statusDisponivel) {
      throw Exception(
          'Este veículo não está mais disponível (status atual: ${veiculoAtual['status']}). Atualize a lista e escolha outro.');
    }

    await _db.from('locacoes').insert(locacao.toMap());
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

  Future<List<LaudoManutencao>> buscarLaudos() async {
    final dados = await _db
        .from('laudos_manutencao')
        .select()
        .order('data_registro', ascending: false);
    return dados.map((m) => LaudoManutencao.fromMap(m)).toList();
  }

  /// Salva o laudo e marca o veículo como "Em Manutenção" — assim o
  /// status do veículo fica consistente com o mesmo campo que o
  /// desktop usa (veiculos.status).
  Future<void> salvarLaudo(LaudoManutencao laudo) async {
    await _db.from('laudos_manutencao').insert(laudo.toMap());
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
  Future<Map<String, dynamic>> buscarDadosFinanceiros() async {
    final todasLocacoes = await _db
        .from('locacoes')
        .select('id, data_fim, valor_total, status, clientes(nome), veiculos(modelo, placa)')
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