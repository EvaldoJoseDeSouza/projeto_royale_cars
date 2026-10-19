import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../services/supabase_service.dart';

/// Guarda as listas de clientes (ativos e arquivados) e avisa as telas
/// quando elas mudam (é o "notifyListeners").
class ClienteController extends ChangeNotifier {
  List<Cliente> _clientes = [];
  List<Cliente> _clientesArquivados = [];
  bool isLoading = false;

  List<Cliente> get clientes => List.unmodifiable(_clientes);
  List<Cliente> get clientesArquivados => List.unmodifiable(_clientesArquivados);

  Future<void> carregarClientes() async {
    isLoading = true;
    notifyListeners();
    try {
      _clientes = await SupabaseService.instance.buscarClientes();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> carregarClientesArquivados() async {
    _clientesArquivados = await SupabaseService.instance.buscarClientes(arquivados: true);
    notifyListeners();
  }

  /// Salva e devolve a frase para mostrar na tela. Salva mesmo com a CNH
  /// vencida (o cliente pode estar renovando), mas avisa: o banco não
  /// deixa alugar enquanto a validade não for atualizada.
  Future<String> salvarCliente(Cliente cliente) async {
    await SupabaseService.instance.salvarCliente(cliente);
    await carregarClientes();

    final dias = cliente.diasParaVencerCnh;
    final aviso = dias < 0
        ? ' Atenção: a CNH está vencida. Ele só poderá alugar depois de atualizar a validade.'
        : dias <= 30
            ? ' Atenção: a CNH vence em $dias dia(s).'
            : '';

    return '${cliente.id != null ? 'Cadastro atualizado' : 'Cliente cadastrado'}: ${cliente.nome}.$aviso';
  }

  Future<String> arquivarCliente(int idCliente) async {
    final cliente = await SupabaseService.instance.mudarArquivadoCliente(idCliente, true);
    await carregarClientes();
    return '${cliente.nome} saiu da lista de clientes. O histórico de locações continua guardado.';
  }

  Future<String> reativarCliente(int idCliente) async {
    final cliente = await SupabaseService.instance.mudarArquivadoCliente(idCliente, false);
    await Future.wait([carregarClientesArquivados(), carregarClientes()]);
    return '${cliente.nome} voltou para a lista de clientes.'
        '${cliente.cnhVencida ? ' A CNH está vencida: atualize a validade antes de um novo aluguel.' : ''}';
  }
}
