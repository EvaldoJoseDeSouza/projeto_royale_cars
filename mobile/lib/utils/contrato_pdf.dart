import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/locacao.dart';
import 'validadores.dart';

/// Gera o PDF do contrato de locação, com os dados do cliente, do
/// veículo, do período, dos valores e a assinatura do cliente.
///
/// Tudo vem do próprio aluguel (a visão vw_locacoes já traz o cliente e
/// o carro). Assim o contrato pode ser gerado a qualquer momento, até
/// para um cliente ou carro que depois foi arquivado.
///
/// 🌟 Esta é a peça central da funcionalidade de "assinatura de
/// contratos" apontada como faltante na avaliação da banca.
class ContratoPdf {
  static Future<void> gerarEAbrir({
    required Locacao locacao,
    Uint8List? assinaturaPng, // a imagem da assinatura (vem do bucket "contratos")
  }) async {
    final documento = pw.Document();
    final imagemAssinatura = assinaturaPng == null ? null : pw.MemoryImage(assinaturaPng);
    final l = locacao;

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
                  'CONTRATO DE LOCAÇÃO DE VEÍCULO Nº ${l.id}',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text('Royale Cars', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              ),
              pw.SizedBox(height: 24),

              _secao('DADOS DO CLIENTE'),
              _linha('Nome', l.nomeCliente),
              _linha('CPF', mascaraCpf(l.cpfCliente)),
              _linha('CNH', l.cnhCliente),
              _linha('Telefone', mascaraTelefone(l.telefoneCliente)),
              if (l.enderecoCliente != null && l.enderecoCliente!.isNotEmpty) _linha('Endereço', l.enderecoCliente!),
              pw.SizedBox(height: 16),

              _secao('DADOS DO VEÍCULO'),
              _linha('Veículo', '${l.nomeVeiculo}${l.ano > 0 ? ' ${l.ano}' : ''}'),
              _linha('Placa', l.placaFormatada),
              // (No PDF, só caracteres comuns: a fonte padrão não tem o travessão "—")
              _linha('Quilometragem na retirada', l.kmSaida == null ? '-' : '${l.kmSaida} km'),
              pw.SizedBox(height: 16),

              _secao('CONDIÇÕES DA LOCAÇÃO'),
              _linha('Data de retirada', dataBr(l.dataRetirada)),
              _linha('Devolução prevista', dataBr(l.dataPrevista)),
              _linha('Diária combinada', moeda(l.valorDiaria)),
              _linha('Valor previsto', '${moeda(l.valorPrevisto)} (${l.diasPrevistos} diária(s))'),

              // Depois da devolução, o contrato mostra o fechamento
              if (l.dataDevolucao != null) ...[
                pw.SizedBox(height: 16),
                _secao('FECHAMENTO'),
                _linha('Data da devolução', dataBr(l.dataDevolucao!)),
                if (l.kmRetorno != null) _linha('Quilometragem na devolução', '${l.kmRetorno} km (${l.kmRodados} km rodados)'),
                if (l.diasAtraso > 0) _linha('Atraso', '${l.diasAtraso} dia(s): ${moeda(l.valorAtraso)}'),
                if (l.taxasExtras > 0) _linha('Taxas extras', '${moeda(l.taxasExtras)} (${l.taxasMotivo ?? ''})'),
                _linha('Valor total', moeda(l.valorTotal)),
              ],
              if (l.cancelada) ...[
                pw.SizedBox(height: 16),
                _secao('CONTRATO CANCELADO (sem cobrança)'),
              ],
              pw.SizedBox(height: 24),

              pw.Text(
                'O(A) locatário(a) acima identificado(a) declara estar de acordo com os termos '
                'desta locação, comprometendo-se a devolver o veículo nas condições em que o '
                'recebeu, na data prevista, e a ressarcir a locadora por quaisquer avarias '
                'causadas durante o período de uso. Cada dia além da data prevista é cobrado '
                'pela diária combinada.',
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
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1))),
                ),
              pw.SizedBox(height: 4),
              pw.Text(l.nomeCliente, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'contrato-${l.id}.pdf',
      onLayout: (formato) => documento.save(),
    );
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
          pw.Expanded(child: pw.Text(valor, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold))),
        ],
      ),
    );
  }
}
