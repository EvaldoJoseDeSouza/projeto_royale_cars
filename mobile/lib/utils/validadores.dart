/// Validadores e máscaras reutilizados nos formulários do app.
///
/// A avaliação da banca apontou falta de validação nos campos ("podia
/// colocar o que quisesse em tudo") — este arquivo centraliza a validação
/// de verdade (não só formatação visual) para CPF, telefone, placa e
/// e-mail, usados em todos os formulários de cadastro.
library;

/// Tira tudo que não é número: "529.982.247-25" → "52998224725".
/// O banco guarda CPF, CNH e telefone assim (só números).
String soDigitos(String valor) => valor.replaceAll(RegExp(r'\D'), '');

/// Nome e sobrenome (a mesma regra do banco: pelo menos 2 palavras e
/// entre 5 e 150 letras).
bool nomeCompletoValido(String valor) {
  final nome = valor.trim().replaceAll(RegExp(r'\s+'), ' ');
  return nome.length >= 5 && nome.length <= 150 && nome.contains(' ');
}

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
    return '($digitos';
  }
  return digitos;
}

/// DDDs que existem no Brasil (a mesma lista do banco: validar_telefone).
const _dddsValidos = {
  11, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 24, 27, 28, 31, 32, 33, 34, 35, 37, 38,
  41, 42, 43, 44, 45, 46, 47, 48, 49, 51, 53, 54, 55, 61, 62, 63, 64, 65, 66, 67, 68, 69,
  71, 73, 74, 75, 77, 79, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92, 93, 94, 95, 96, 97, 98, 99,
};

/// Telefone brasileiro, com a mesma regra do banco:
///  - 11 números (celular): DDD + 9 + 8 números. Ex.: (19) 99999-9999
///  - 10 números (fixo): DDD + número começando com 2, 3, 4 ou 5
bool telefoneValido(String valor) {
  final digitos = soDigitos(valor);
  if (digitos.length != 10 && digitos.length != 11) return false;
  if (!_dddsValidos.contains(int.parse(digitos.substring(0, 2)))) return false;

  final terceiro = digitos[2];
  return digitos.length == 11 ? terceiro == '9' : '2345'.contains(terceiro);
}

/// CNH com os dígitos verificadores (a mesma conta do banco: validar_cnh).
/// Existem 2 versões do cálculo em uso no país; vale se passar em uma delas.
bool cnhValida(String valor) {
  final cnh = soDigitos(valor);
  if (cnh.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(cnh)) return false;

  // d[1] a d[11], igual ao banco (d[0] fica sem uso, só para os índices baterem)
  final d = [0, ...cnh.split('').map(int.parse)];

  // Versão 1
  var soma = 0;
  for (var i = 1; i <= 9; i++) {
    soma += d[i] * (10 - i);
  }
  var dv1 = soma % 11;
  var desconto = 0;
  if (dv1 >= 10) {
    dv1 = 0;
    desconto = 2;
  }

  soma = 0;
  for (var i = 1; i <= 9; i++) {
    soma += d[i] * i;
  }
  var resto = soma % 11;
  var dv2 = resto >= 10 ? 0 : resto - desconto;

  if (dv1 == d[10] && dv2 == d[11]) return true;

  // Versão 2 (Detran-PR)
  soma = 0;
  for (var i = 1; i <= 9; i++) {
    soma += d[i] * (i + 1);
  }
  resto = soma % 11;
  dv1 = resto <= 1 ? 0 : 11 - resto;

  soma = dv1 * 2;
  for (var i = 1; i <= 9; i++) {
    soma += d[i] * (i + 2);
  }
  resto = soma % 11;
  dv2 = resto <= 1 ? 0 : 11 - resto;

  return dv1 == d[10] && dv2 == d[11];
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

/// Deixa placa ou chassi como o banco guarda: maiúsculas, sem hífen,
/// ponto ou espaço. "abc-1234" → "ABC1234"
String limparCodigo(String valor) => valor.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Chassi (a mesma regra do banco): 17 letras/números, sem I, O e Q
/// (para não confundir com 1 e 0), e não pode ser tudo igual.
bool chassiValido(String valor) {
  final chassi = limparCodigo(valor);
  return RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(chassi) && !RegExp(r'^(.)\1{16}$').hasMatch(chassi);
}

/// Lê o dinheiro digitado: "1.234,56", "350,00" ou "350.00" → número.
/// Devolve null se não der para entender.
double? lerDinheiro(String valor) {
  var texto = valor.replaceAll(RegExp(r'[^\d,\.]'), ''); // tira "R$" e espaços
  if (texto.contains(',')) {
    // Jeito brasileiro: ponto separa milhar e vírgula separa centavos
    texto = texto.replaceAll('.', '').replaceAll(',', '.');
  }
  final numero = double.tryParse(texto);
  return numero == null ? null : (numero * 100).round() / 100;
}

/// Dinheiro no formato brasileiro: 1234.5 → "R$ 1.234,50"
String moeda(double valor) {
  final partes = valor.abs().toStringAsFixed(2).split('.');
  final inteiro = partes[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  return '${valor < 0 ? '-' : ''}R\$ $inteiro,${partes[1]}';
}

/// Aceita placa no padrão antigo (LLL-NNNN) ou Mercosul (LLLNLNN).
bool placaValida(String valor) {
  final v = valor.replaceAll('-', '').toUpperCase();
  final padraoAntigo = RegExp(r'^[A-Z]{3}[0-9]{4}$');
  final padraoMercosul = RegExp(r'^[A-Z]{3}[0-9][A-Z][0-9]{2}$');
  return padraoAntigo.hasMatch(v) || padraoMercosul.hasMatch(v);
}

/// A mesma regra do banco: algo@algo.algo, sem espaços.
/// (A versão antiga recusava e-mails .com.br, como joao@empresa.com.br.)
bool emailValido(String valor) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(valor.trim());
}

/// Data no formato que o banco entende: "2027-03-15".
String dataParaBanco(DateTime data) {
  final mes = data.month.toString().padLeft(2, '0');
  final dia = data.day.toString().padLeft(2, '0');
  return '${data.year}-$mes-$dia';
}

/// Data no formato brasileiro, para mostrar na tela: "15/03/2027".
String dataBr(DateTime data) {
  final mes = data.month.toString().padLeft(2, '0');
  final dia = data.day.toString().padLeft(2, '0');
  return '$dia/$mes/${data.year}';
}

/// Validador genérico de campo obrigatório, pronto pra usar em
/// TextFormField(validator: obrigatorio).
String? obrigatorio(String? valor, [String rotulo = 'Este campo']) {
  if (valor == null || valor.trim().isEmpty) {
    return '$rotulo é obrigatório';
  }
  return null;
}
