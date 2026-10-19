import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cliente.dart';
import '../models/locacao.dart';
import '../models/manutencao.dart';
import '../models/painel.dart';
import '../models/usuario.dart';
import '../models/veiculo.dart';
import '../utils/validadores.dart';
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
  // FROTA (veículos) — as mesmas regras da web e do desktop:
  //  - O status NÃO é escolhido no formulário: muda sozinho com os
  //    aluguéis e as manutenções (o banco recusa mudança à mão).
  //  - O banco confere placa, chassi, duplicados e só deixa arquivar
  //    carro Disponível.
  // ---------------------------------------------------------------------

  /// Frases para cada regra do banco (nomes em banco/01 e banco/02)
  static const _mensagensVeiculos = {
    'veiculos_marca_check': 'Informe a marca.',
    'veiculos_modelo_check': 'Informe o modelo.',
    'veiculos_ano_check': 'Ano inválido.',
    'veiculos_placa_check': 'Placa inválida. Use o padrão antigo (ABC-1234) ou Mercosul (ABC1D23).',
    'veiculos_chassi_check': 'Chassi inválido. São 17 letras/números, sem as letras I, O e Q.',
    'veiculos_valor_diaria_check': 'Informe um valor de diária maior que zero.',
    'veiculos_quilometragem_check': 'A quilometragem não pode ser negativa.',
  };

  static const _duplicadosVeiculos = {
    'veiculos_placa_key': ('placa', 'Esta placa'),
    'veiculos_chassi_key': ('chassi', 'Este chassi'),
  };

  Future<List<Veiculo>> buscarFrota({bool arquivados = false}) async {
    final dados = await _db
        .from('veiculos')
        .select(Veiculo.colunas)
        .eq('arquivado', arquivados)
        .order('marca')
        .order('modelo');
    return dados.map((m) => Veiculo.fromMap(m)).toList();
  }

  /// Endereço da foto do veículo. O bucket "veiculos" é público, então
  /// basta montar o link (igual à web e ao desktop). Sem foto → null.
  String? urlFoto(String? caminho) {
    if (caminho == null || caminho.isEmpty) return null;
    return _db.storage.from('veiculos').getPublicUrl(caminho);
  }

  /// Cadastra (sem id) ou edita (com id).
  Future<void> salvarVeiculo(Veiculo veiculo) async {
    final dados = veiculo.toMap();

    try {
      if (veiculo.id != null) {
        await _db.from('veiculos').update(dados).eq('id', veiculo.id!);
      } else {
        await _db.from('veiculos').insert(dados);
      }
    } on PostgrestException catch (erro) {
      debugPrint('[FROTA] Banco recusou: ${erro.code} ${erro.message}');
      final duplicado = _duplicadosVeiculos[nomeDaRegra(erro)];

      if (duplicado != null) {
        throw Exception(await _veiculoDuplicado(duplicado.$1, duplicado.$2, dados[duplicado.$1], veiculo.id));
      }
      throw Exception(traduzirErroBanco(erro, _mensagensVeiculos));
    } catch (erro) {
      throw Exception(traduzirErroBanco(erro));
    }
  }

  /// Placa ou chassi repetido: diz de qual carro é.
  Future<String> _veiculoDuplicado(String coluna, String rotulo, Object? valor, int? idAtual) async {
    try {
      final dono = await _db
          .from('veiculos')
          .select('marca, modelo, arquivado')
          .eq(coluna, valor ?? '')
          .neq('id', idAtual ?? 0)
          .maybeSingle();

      if (dono == null) return '$rotulo já está cadastrado.';
      final carro = '${dono['marca']} ${dono['modelo']}';
      if (dono['arquivado'] == true) {
        return '$rotulo pertence ao $carro, que está arquivado. Reative esse veículo em vez de cadastrar de novo.';
      }
      return '$rotulo já pertence ao $carro.';
    } catch (_) {
      return '$rotulo já está cadastrado.';
    }
  }

  /// Arquiva ou reativa. O banco só deixa arquivar carro Disponível
  /// (não alugado nem na oficina) e, ao reativar, ele volta Disponível.
  Future<Veiculo> mudarArquivadoVeiculo(int idVeiculo, bool arquivar) async {
    try {
      final dados = await _db
          .from('veiculos')
          .update({'arquivado': arquivar})
          .eq('id', idVeiculo)
          .select(Veiculo.colunas)
          .single();
      return Veiculo.fromMap(dados);
    } catch (erro) {
      throw Exception(traduzirErroBanco(erro, _mensagensVeiculos));
    }
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
  // LOCAÇÕES — o app não grava direto na tabela: chama as funções do
  // banco, as MESMAS da web e do desktop. Cada função faz tudo de uma
  // vez (tudo ou nada) e duas pessoas não conseguem alugar o mesmo carro.
  // ---------------------------------------------------------------------

  Future<List<Locacao>> buscarLocacoesAtivas() async {
    final dados = await _db
        .from('vw_locacoes')
        .select(Locacao.colunas)
        .eq('status', Locacao.statusEmAndamento)
        .order('data_prevista');
    return dados.map((m) => Locacao.fromMap(m)).toList();
  }

  Future<List<Locacao>> buscarLocacoesHistorico() async {
    final dados = await _db
        .from('vw_locacoes')
        .select(Locacao.colunas)
        .eq('status', Locacao.statusFinalizada)
        .order('data_devolucao', ascending: false)
        .limit(100);
    return dados.map((m) => Locacao.fromMap(m)).toList();
  }

  /// Envia a assinatura (PNG) para o bucket privado "contratos" e
  /// devolve o caminho do arquivo, que vai junto para registrar_aluguel.
  /// Ex.: "2026/10/1729340000000-cliente-12.png"
  Future<String> enviarAssinatura(Uint8List png, int clienteId) async {
    final agora = DateTime.now();
    final mes = agora.month.toString().padLeft(2, '0');
    final caminho = '${agora.year}/$mes/${agora.millisecondsSinceEpoch}-cliente-$clienteId.png';

    try {
      await _db.storage.from('contratos').uploadBinary(
            caminho,
            png,
            fileOptions: const FileOptions(contentType: 'image/png'),
          );
      return caminho;
    } catch (erro) {
      debugPrint('[ASSINATURA] Falha ao enviar: $erro');
      throw Exception('Não foi possível guardar a assinatura. Verifique a internet e tente de novo.');
    }
  }

  /// Registra a retirada pela função do banco. Ela confere tudo (cliente
  /// ativo, CNH válida até o fim do aluguel, carro disponível, datas e
  /// quilometragem), calcula o valor com a diária do carro, marca o carro
  /// como Alugado e anota no histórico. Devolve o número do aluguel.
  Future<int> registrarAluguel({
    required int clienteId,
    required int veiculoId,
    required DateTime dataRetirada,
    required DateTime dataPrevista,
    required int kmSaida,
    String? observacoes,
    String? assinaturaPath,
  }) async {
    try {
      final id = await _db.rpc('registrar_aluguel', params: {
        'p_cliente_id': clienteId,
        'p_veiculo_id': veiculoId,
        'p_data_retirada': dataParaBanco(dataRetirada),
        'p_data_prevista': dataParaBanco(dataPrevista),
        'p_km_saida': kmSaida,
        'p_observacoes': observacoes,
        'p_assinatura_path': assinaturaPath,
      });
      return (id as num).toInt();
    } catch (erro) {
      throw Exception(traduzirErroBanco(erro, {
        // Duas pessoas tentaram alugar o mesmo carro no mesmo instante
        'uk_locacao_ativa_por_veiculo': 'Este carro acabou de ser alugado por outra pessoa. Escolha outro.',
      }));
    }
  }

  /// As abas da lista de locações (as mesmas da web). "Em andamento" e
  /// "Atrasados" usam o status_exibicao da visão, que já diz "Atrasada"
  /// quando passou da data prevista.
  static const abasLocacao = {
    'Em andamento': ('status_exibicao', 'Em andamento'),
    'Atrasados': ('status_exibicao', 'Atrasada'),
    'Finalizados': ('status', 'Finalizada'),
    'Cancelados': ('status', 'Cancelada'),
  };

  Future<List<Locacao>> buscarLocacoes(String aba) async {
    final (coluna, valor) = abasLocacao[aba]!;
    final emAberto = coluna == 'status_exibicao';

    final dados = await _db
        .from('vw_locacoes')
        .select(Locacao.colunas)
        .eq(coluna, valor)
        // Abertos: o que vence primeiro em cima. Encerrados: o mais recente em cima.
        .order(emAberto ? 'data_prevista' : 'id', ascending: emAberto)
        .limit(200);
    return dados.map((m) => Locacao.fromMap(m)).toList();
  }

  /// Um aluguel só (para atualizar a tela de detalhes).
  Future<Locacao> buscarLocacao(int id) async {
    final dados = await _db.from('vw_locacoes').select(Locacao.colunas).eq('id', id).single();
    return Locacao.fromMap(dados);
  }

  /// Baixa a imagem da assinatura do bucket privado "contratos".
  /// (Privado = só quem está logado e pode ver locações consegue baixar.)
  Future<Uint8List?> baixarAssinatura(String? caminho) async {
    if (caminho == null || caminho.isEmpty) return null;
    try {
      return await _db.storage.from('contratos').download(caminho);
    } catch (erro) {
      debugPrint('[ASSINATURA] Falha ao baixar: $erro');
      return null; // sem a imagem, o contrato sai com a linha para assinar
    }
  }

  /// Registra a devolução pela função do banco (a mesma da web e do
  /// desktop). Ela fecha o aluguel, calcula dias, atraso e total, atualiza
  /// a quilometragem e libera o carro, ou manda para a oficina se voltou
  /// com defeito. Devolve o resumo calculado pelo banco, por exemplo:
  /// {"dias": 3, "dias_atraso": 1, "valor_total": 1650.0, "status_veiculo": "Disponível", ...}
  Future<Map<String, dynamic>> registrarDevolucao({
    required int locacaoId,
    required DateTime dataDevolucao,
    int? kmRetorno,
    double taxasExtras = 0,
    String? taxasMotivo,
    String? observacoes,
    String? defeito,
    String? oficina,
  }) async {
    try {
      final resumo = await _db.rpc('registrar_devolucao', params: {
        'p_locacao_id': locacaoId,
        'p_data_devolucao': dataParaBanco(dataDevolucao),
        'p_km_retorno': kmRetorno,
        'p_taxas_extras': taxasExtras,
        'p_taxas_motivo': taxasMotivo,
        'p_observacoes': observacoes,
        'p_defeito': defeito,
        'p_oficina': oficina,
      });
      return Map<String, dynamic>.from(resumo as Map);
    } catch (erro) {
      throw Exception(traduzirErroBanco(erro, {
        'km_retorno_valido': 'A quilometragem de retorno não pode ser menor que a de saída.',
        'taxas_com_motivo': 'Informe o motivo das taxas extras (ex.: combustível, limpeza, avaria).',
      }));
    }
  }

  /// Cancela um aluguel em andamento, sem cobrar, e libera o carro.
  /// Pede a permissão "locacoes_cancelar" (o banco confere).
  Future<void> cancelarAluguel(int locacaoId, String motivo) async {
    try {
      await _db.rpc('cancelar_aluguel', params: {'p_locacao_id': locacaoId, 'p_motivo': motivo});
    } catch (erro) {
      throw Exception(traduzirErroBanco(erro));
    }
  }

  // ---------------------------------------------------------------------
  // MANUTENÇÃO — pelas funções do banco, as MESMAS da web e do desktop:
  //   abrir_manutencao    → registra a ida para a oficina (com a vistoria
  //                         opcional) e marca o carro "Em manutenção"
  //   concluir_manutencao → registra serviço, custo e data e libera o carro
  // O custo entra no Financeiro das 3 plataformas.
  // ---------------------------------------------------------------------

  Future<List<Manutencao>> buscarManutencoes({required bool emAndamento}) async {
    final dados = await _db
        .from('manutencoes')
        .select(Manutencao.colunas)
        .eq('status', emAndamento ? Manutencao.statusEmAndamento : Manutencao.statusConcluida)
        .order(emAndamento ? 'data_entrada' : 'data_liberacao', ascending: emAndamento)
        .limit(200);
    return dados.map((m) => Manutencao.fromMap(m)).toList();
  }

  /// Envia o carro para a oficina. O banco só aceita carro Disponível
  /// (o que volta de aluguel com defeito vai pela devolução). Devolve o id.
  Future<int> abrirManutencao({
    required int veiculoId,
    required String defeito,
    String? oficina,
    required DateTime dataEntrada,
    DateTime? previsao,
    List<bool?> checklist = const [null, null, null, null], // motor, freios, pneus, óleo
  }) async {
    try {
      final id = await _db.rpc('abrir_manutencao', params: {
        'p_veiculo_id': veiculoId,
        'p_defeito': defeito,
        'p_oficina': oficina,
        'p_data_entrada': dataParaBanco(dataEntrada),
        'p_previsao': previsao == null ? null : dataParaBanco(previsao),
        'p_motor_ok': checklist[0],
        'p_freios_ok': checklist[1],
        'p_pneus_ok': checklist[2],
        'p_oleo_ok': checklist[3],
      });
      return (id as num).toInt();
    } catch (erro) {
      throw Exception(traduzirErroBanco(erro, {
        'manutencoes_defeito_check': 'Descreva o defeito (pelo menos 5 letras).',
        'manutencoes_check': 'A previsão de liberação não pode ser antes da entrada.',
        'uk_manutencao_aberta_por_veiculo': 'Este carro já está na oficina.',
      }));
    }
  }

  /// Libera o carro: serviço feito, custo (0 se foi na garantia) e data.
  Future<void> concluirManutencao({
    required int manutencaoId,
    required DateTime dataLiberacao,
    required String servico,
    required double custo,
  }) async {
    try {
      await _db.rpc('concluir_manutencao', params: {
        'p_manutencao_id': manutencaoId,
        'p_data_liberacao': dataParaBanco(dataLiberacao),
        'p_servico': servico,
        'p_custo': custo,
      });
    } catch (erro) {
      throw Exception(traduzirErroBanco(erro));
    }
  }

  // ---------------------------------------------------------------------
  // PAINEL E FINANCEIRO — pelas VISÕES do banco (as mesmas da web e do
  // desktop). Antes o celular baixava todas as locações e somava aqui;
  // agora quem soma é o banco, e os números batem nas 3 plataformas.
  // ---------------------------------------------------------------------

  Future<SituacaoFrota> buscarSituacaoFrota() async {
    final dados = await _db.from('vw_situacao_frota').select().maybeSingle();
    return dados == null ? const SituacaoFrota() : SituacaoFrota.fromMap(dados);
  }

  /// Os alertas que esta pessoa pode ver (a visão respeita as permissões).
  Future<List<Alerta>> buscarAlertas() async {
    final dados = await _db
        .from('vw_alertas')
        .select('tipo, referencia_id, titulo, detalhe, data')
        .order('data')
        .limit(50);
    return dados.map((m) => Alerta.fromMap(m)).toList();
  }

  /// Os últimos 12 meses (vazio para quem não tem a permissão financeiro).
  Future<List<MesFinanceiro>> buscarMeses() async {
    final dados = await _db
        .from('vw_faturamento_mensal')
        .select('mes, faturamento, alugueis, manutencao')
        .order('mes');
    return dados.map((m) => MesFinanceiro.fromMap(m)).toList();
  }

  /// O Financeiro de um período: a MESMA conta do desktop (painel.js).
  Future<ResumoFinanceiro> buscarFinanceiro(DateTime inicio, DateTime fim) async {
    final de = dataParaBanco(inicio);
    final ate = dataParaBanco(fim);

    // Future.wait: faz as 4 perguntas ao banco AO MESMO TEMPO
    final respostas = await Future.wait<dynamic>([
      // Aluguéis finalizados no período, com cliente e carro "pendurados"
      _db
          .from('locacoes')
          .select('id, data_devolucao, valor_total, taxas_extras, dias_atraso, clientes(nome), veiculos(marca, modelo, placa)')
          .eq('status', Locacao.statusFinalizada)
          .gte('data_devolucao', de)
          .lte('data_devolucao', ate)
          .order('data_devolucao', ascending: false),
      // Manutenções concluídas (pagas) no período
      _db
          .from('manutencoes')
          .select('custo')
          .eq('status', Manutencao.statusConcluida)
          .gte('data_liberacao', de)
          .lte('data_liberacao', ate),
      // O que ainda vai entrar: aluguéis que estão na rua agora
      _db.from('locacoes').select('valor_previsto').eq('status', Locacao.statusEmAndamento),
      buscarMeses(),
    ]);

    double soma(List lista, String campo) =>
        lista.fold<double>(0, (total, linha) => total + ((linha[campo] as num?)?.toDouble() ?? 0));

    final entradas = List<Map<String, dynamic>>.from(respostas[0] as List);

    return ResumoFinanceiro(
      faturamento: soma(entradas, 'valor_total'),
      alugueis: entradas.length,
      gastoManutencao: soma(respostas[1] as List, 'custo'),
      aReceber: soma(respostas[2] as List, 'valor_previsto'),
      entradas: entradas,
      meses: respostas[3] as List<MesFinanceiro>,
    );
  }

  // ---------------------------------------------------------------------
  // MINHA CONTA — cada pessoa muda só o próprio NOME. Cargo, e-mail e
  // permissões só o chefe muda (o banco garante: tg_perfis_antes).
  // ---------------------------------------------------------------------

  Future<void> salvarMeuNome(String usuarioId, String nome) async {
    try {
      await _db.from('perfis').update({'nome': nome}).eq('id', usuarioId);
    } catch (erro) {
      throw Exception(traduzirErroBanco(erro, {
        'perfis_nome_check': 'O nome precisa ter entre 3 e 100 caracteres.',
      }));
    }
  }
}