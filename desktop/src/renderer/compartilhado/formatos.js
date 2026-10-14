// =====================================================================
//  Formatos e máscaras (arquivo compartilhado)
// ---------------------------------------------------------------------
//  Regra do sistema unificado: o BANCO guarda só os números
//  (CPF "12345678909", telefone "19999998888") e as datas no formato
//  "AAAA-MM-DD". A MÁSCARA é só na tela, para ajudar quem lê e digita.
//
//  Quem usa carrega com:
//     <script src="../../compartilhado/formatos.js"></script>
// =====================================================================

// "123.456.789-09" → "12345678909"
function soDigitos(texto) {
  return String(texto ?? '').replace(/\D/g, '');
}

// "12345678909" → "123.456.789-09" (também serve enquanto a pessoa digita)
function formatarCpf(valor) {
  const d = soDigitos(valor).slice(0, 11);
  if (d.length > 9) return d.replace(/^(\d{3})(\d{3})(\d{3})(\d{1,2})$/, '$1.$2.$3-$4');
  if (d.length > 6) return d.replace(/^(\d{3})(\d{3})(\d{1,3})$/, '$1.$2.$3');
  if (d.length > 3) return d.replace(/^(\d{3})(\d{1,3})$/, '$1.$2');
  return d;
}

// "19999998888" → "(19) 99999-8888"   |   "1933334444" → "(19) 3333-4444"
function formatarTelefone(valor) {
  const d = soDigitos(valor).slice(0, 11);
  if (d.length > 10) return d.replace(/^(\d{2})(\d{5})(\d{4})$/, '($1) $2-$3');
  if (d.length > 6) return d.replace(/^(\d{2})(\d{4})(\d{1,4})$/, '($1) $2-$3');
  if (d.length > 2) return d.replace(/^(\d{2})(\d{1,5})$/, '($1) $2');
  if (d.length > 0) return `(${d}`;
  return '';
}

// Placa: o banco guarda "ABC1234" ou "ABC1D23" (sem hífen).
// Na tela, o padrão antigo ganha o hífen: "ABC-1234". O Mercosul fica igual.
// Também serve enquanto a pessoa digita (tira o que não é letra/número).
function formatarPlaca(valor) {
  const p = String(valor ?? '').toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 7);
  return /^[A-Z]{3}\d{4}$/.test(p) ? `${p.slice(0, 3)}-${p.slice(3)}` : p;
}

// 1234.5 → "R$ 1.234,50"
function formatarDinheiro(valor) {
  return Number(valor || 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}

// Máscara de dinheiro para digitar: cada número entra pela direita,
// como numa máquina de cartão. "59000" → "R$ 590,00"
function mascaraDinheiro(valor) {
  const centavos = soDigitos(valor);
  return centavos ? formatarDinheiro(Number(centavos) / 100) : '';
}

// 24260 → "24.260 km"
function formatarKm(valor) {
  return `${Number(valor || 0).toLocaleString('pt-BR')} km`;
}

// "2027-03-15" → "15/03/2027" (sem passar por Date: não sofre com fuso horário)
function formatarData(dataTexto) {
  if (!dataTexto) return '-';
  const [ano, mes, dia] = String(dataTexto).slice(0, 10).split('-');
  return `${dia}/${mes}/${ano}`;
}

// Hoje no formato "AAAA-MM-DD", no horário do computador
function hojeTexto() {
  const d = new Date();
  d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
  return d.toISOString().slice(0, 10);
}

// Quantos dias faltam até a data (negativo = já passou)
function diasAte(dataTexto) {
  return Math.round((new Date(dataTexto) - new Date(hojeTexto())) / 86400000);
}

// Liga a máscara num campo: a cada tecla, reescreve o texto formatado.
// Ex.: aplicarMascara(document.getElementById('cpf'), formatarCpf)
function aplicarMascara(campo, formatar) {
  if (!campo) return;
  campo.addEventListener('input', () => {
    campo.value = formatar(campo.value);
  });
}

// Troca < > & " ' por códigos seguros antes de colocar um texto do banco
// dentro de innerHTML. Assim um nome como "<b>Ana</b>" aparece escrito,
// em vez de virar HTML de verdade.
function escaparHtml(texto) {
  return String(texto ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  })[c]);
}
