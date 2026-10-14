import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../services/supabase_service.dart';

class ClienteController extends ChangeNotifier {
  List<Cliente> _clientes = [];
  List<Cliente> _clientesArquivados = [];
  bool isLoading = false;

  List<Cliente> get clientes => List.unmodifiable(_clientes);
  List<Cliente> get clientesArquivados => List.unmodifiable(_clientesArquivados);

  Future<void> carregarClientes(int idEmpresa) async {
    isLoading = true;
    notifyListeners();
    try {
      _clientes = await SupabaseService.instance.buscarClientes(idEmpresa);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> carregarClientesArquivados(int idEmpresa) async {
    _clientesArquivados = await SupabaseService.instance.buscarClientesArquivados(idEmpresa);
    notifyListeners();
  }

  Future<void> salvarCliente(Cliente cliente, int idEmpresa) async {
    await SupabaseService.instance.salvarCliente(cliente, idEmpresa);
    await carregarClientes(idEmpresa);
  }

  Future<void> arquivarCliente(int idCliente, int idEmpresa) async {
    await SupabaseService.instance.arquivarCliente(idCliente);
    await carregarClientes(idEmpresa);
  }

  Future<void> reativarCliente(int idCliente, int idEmpresa) async {
    await SupabaseService.instance.reativarCliente(idCliente);
    await carregarClientesArquivados(idEmpresa);
    await carregarClientes(idEmpresa);
  }
}
