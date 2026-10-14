/// Validadores e máscaras reutilizados nos formulários do app.
///
/// A avaliação da banca apontou falta de validação nos campos ("podia
/// colocar o que quisesse em tudo") — este arquivo centraliza a validação
/// de verdade (não só formatação visual) para CPF, telefone, placa e
/// e-mail, usados em todos os formulários de cadastro.
library;

/// Valida um CPF usando o algoritmo oficial de dígitos verificadores
/// (não apenas o formato) — rejeita CPFs com todos os dígitos iguais
/// (ex: 111.111.111-11) e dígitos verificadores incorretos.
bool cpfValido(String cpfComOuSemMascara) {
  final digitos = cpfComOuSemMascara.replaceAll(RegExp(r'\D'), '');
  if (digitos.length != 11) return false;
  if (RegExp(r'^(\d)\1{10}$').hasMatch(digitos)) return false;

  List<int> nums = digitos.split('').map(int.parse).toList();

  int calcularDigito(List<int> base) {
    int soma = 0;
    int peso = base.length + 1;
    for (final n in base) {
      soma += n * peso;
      peso--;
    }
    final resto = soma % 11;
    return resto < 2 ? 0 : 11 - resto;
  }

  final digito1 = calcularDigito(nums.sublist(0, 9));
  if (digito1 != nums[9]) return false;

  final digito2 = calcularDigito(nums.sublist(0, 10));
  if (digito2 != nums[10]) return false;

  return true;
}

/// Aplica a máscara 000.000.000-00 progressivamente enquanto o usuário digita.
String mascaraCpf(String valorAtual) {
  var digitos = valorAtual.replaceAll(RegExp(r'\D'), '');
  if (digitos.length > 11) digitos = digitos.substring(0, 11);

  if (digitos.length > 9) {
    return digitos.replaceAllMapped(
        RegExp(r'^(\d{3})(\d{3})(\d{3})(\d{1,2})$'),
        (m) => '${m[1]}.${m[2]}.${m[3]}-${m[4]}');
  } else if (digitos.length > 6) {
    return digitos.replaceAllMapped(
        RegExp(r'^(\d{3})(\d{3})(\d{1,3})$'), (m) => '${m[1]}.${m[2]}.${m[3]}');
  } else if (digitos.length > 3) {
    return digitos.replaceAllMapped(
        RegExp(r'^(\d{3})(\d{1,3})$'), (m) => '${m[1]}.${m[2]}');
  }
  return digitos;
}

/// Aplica a máscara (00) 00000-0000 progressivamente.
String mascaraTelefone(String valorAtual) {
  var digitos = valorAtual.replaceAll(RegExp(r'\D'), '');
  if (digitos.length > 11) digitos = digitos.substring(0, 11);

  if (digitos.length > 10) {
    return digitos.replaceAllMapped(
        RegExp(r'^(\d{2})(\d{5})(\d{4})$'), (m) => '(${m[1]}) ${m[2]}-${m[3]}');
  } else if (digitos.length > 6) {
    return digitos.replaceAllMapped(
        RegExp(r'^(\d{2})(\d{4})(\d{4})$'), (m) => '(${m[1]}) ${m[2]}-${m[3]}');
  } else if (digitos.length > 2) {
    return digitos.replaceAllMapped(
        RegExp(r'^(\d{2})(\d{1,4})$'), (m) => '(${m[1]}) ${m[2]}');
  } else if (digitos.isNotEmpty) {
    return '(${digitos}';
  }
  return digitos;
}

/// Um telefone brasileiro válido tem 10 dígitos (fixo) ou 11 (celular com 9).
bool telefoneValido(String valor) {
  final digitos = valor.replaceAll(RegExp(r'\D'), '');
  return digitos.length == 10 || digitos.length == 11;
}

/// Aplica a máscara de placa, aceitando tanto o padrão antigo
/// (ABC-1234) quanto o padrão Mercosul (ABC1D23).
String mascaraPlaca(String valorAtual) {
  var v = valorAtual.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
  if (v.length > 7) v = v.substring(0, 7);
  if (v.length == 7 && RegExp(r'^[A-Z]{3}[0-9]{4}$').hasMatch(v)) {
    return v.replaceAllMapped(
        RegExp(r'^([A-Z]{3})([0-9]{4})$'), (m) => '${m[1]}-${m[2]}');
  }
  return v;
}

/// Aceita placa no padrão antigo (LLL-NNNN) ou Mercosul (LLLNLNN).
bool placaValida(String valor) {
  final v = valor.replaceAll('-', '').toUpperCase();
  final padraoAntigo = RegExp(r'^[A-Z]{3}[0-9]{4}$');
  final padraoMercosul = RegExp(r'^[A-Z]{3}[0-9][A-Z][0-9]{2}$');
  return padraoAntigo.hasMatch(v) || padraoMercosul.hasMatch(v);
}

bool emailValido(String valor) {
  return RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$').hasMatch(valor.trim());
}

/// Validador genérico de campo obrigatório, pronto pra usar em
/// TextFormField(validator: obrigatorio).
String? obrigatorio(String? valor, [String rotulo = 'Este campo']) {
  if (valor == null || valor.trim().isEmpty) {
    return '$rotulo é obrigatório';
  }
  return null;
}
