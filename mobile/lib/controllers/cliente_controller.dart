import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../services/supabase_service.dart';

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
    _clientesArquivados = await SupabaseService.instance.buscarClientesArquivados();
    notifyListeners();
  }

  Future<void> salvarCliente(Cliente cliente) async {
    await SupabaseService.instance.salvarCliente(cliente);
    await carregarClientes();
  }

  Future<void> arquivarCliente(int idCliente) async {
    await SupabaseService.instance.arquivarCliente(idCliente);
    await carregarClientes();
  }

  Future<void> reativarCliente(int idCliente) async {
    await SupabaseService.instance.reativarCliente(idCliente);
    await carregarClientesArquivados();
    await carregarClientes();
  }
}
