import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/cliente.dart';
import '../models/locacao.dart';
import '../models/veiculo.dart';

/// Gera o PDF do contrato de locação — com os dados do cliente, do
/// veículo, do período, do valor e (se já tiver sido capturada) a
/// assinatura digital do cliente.
///
/// 🌟 Esta é a peça central da funcionalidade de "assinatura de
/// contratos" apontada como faltante na avaliação da banca.
class ContratoPdf {
  static Future<void> gerarEAbrir({
    required Locacao locacao,
    required Cliente cliente,
    required Veiculo veiculo,
    Uint8List? assinaturaPng, // a imagem da assinatura (vem do bucket "contratos")
  }) async {
    final documento = pw.Document();
    final formatoData = DateFormat('dd/MM/yyyy');
    final formatoMoeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final imagemAssinatura = assinaturaPng == null ? null : pw.MemoryImage(assinaturaPng);

    documento.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'CONTRATO DE LOCAÇÃO DE VEÍCULO',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text('Royale Cars', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              ),
              pw.SizedBox(height: 24),

              _secao('DADOS DO CLIENTE'),
              _linha('Nome', cliente.nome),
              _linha('CPF', cliente.cpfFormatado),
              _linha('CNH', cliente.cnh),
              _linha('Telefone', cliente.telefoneFormatado),
              if (cliente.endereco != null && cliente.endereco!.isNotEmpty)
                _linha('Endereço', cliente.endereco!),
              pw.SizedBox(height: 16),

              _secao('DADOS DO VEÍCULO'),
              _linha('Veículo', '${veiculo.marca} ${veiculo.modelo}'),
              _linha('Placa', veiculo.placaFormatada),
              _linha('Quilometragem na retirada', '${locacao.kmSaida ?? veiculo.quilometragem} km'),
              pw.SizedBox(height: 16),

              _secao('CONDIÇÕES DA LOCAÇÃO'),
              _linha('Data de retirada', formatoData.format(locacao.dataRetirada)),
              _linha('Data de devolução prevista', formatoData.format(locacao.dataPrevista)),
              _linha('Valor total', formatoMoeda.format(locacao.valorTotal)),
              pw.SizedBox(height: 24),

              pw.Text(
                'O(A) locatário(a) acima identificado(a) declara estar de acordo com os termos '
                'desta locação, comprometendo-se a devolver o veículo nas condições em que o '
                'recebeu, na data prevista, e a ressarcir a locadora por quaisquer avarias '
                'causadas durante o período de uso.',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 32),

              pw.Text('Assinatura do cliente:', style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 8),
              if (imagemAssinatura != null)
                pw.Container(height: 90, alignment: pw.Alignment.centerLeft, child: pw.Image(imagemAssinatura))
              else
                pw.Container(
                  height: 60,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(width: 1)),
                  ),
                ),
              pw.SizedBox(height: 4),
              pw.Text(cliente.nome, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (formato) => documento.save());
  }

  static pw.Widget _secao(String titulo) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        titulo,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
      ),
    );
  }

  static pw.Widget _linha(String rotulo, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 160, child: pw.Text('$rotulo:', style: const pw.TextStyle(fontSize: 10.5))),
          pw.Expanded(
              child: pw.Text(valor, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold))),
        ],
      ),
    );
  }
}
