import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/order_model.dart';
import '../../models/payment_model.dart';
import 'currency_formatter.dart';
import 'date_formatter.dart';

String _paymentMethodLabel(String method) {
  switch (method) {
    case 'manual_qris':
      return 'QRIS Manual';
    case 'xendit':
      return 'Xendit';
    default:
      return method;
  }
}

pw.Widget _cell(String text, {bool bold = false, bool alignRight = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
      textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
    ),
  );
}

/// Membuat PDF laporan pendapatan dari [payments] (pembayaran lunas),
/// dicocokkan ke [orders] untuk kode pesanan & nama pelanggan.
Future<Uint8List> buildRevenueReportPdf({
  required String periodLabel,
  required List<PaymentModel> payments,
  required List<OrderModel> orders,
}) async {
  final ordersById = {for (final o in orders) o.id: o};
  final total = payments.fold<double>(0, (sum, p) => sum + p.amount);
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Laporan Pendapatan',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(periodLabel, style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 2),
          pw.Text(
            'Dicetak: ${formatTanggalIndo(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 12),
        ],
      ),
      build: (context) => [
        if (payments.isEmpty)
          pw.Text(
            'Tidak ada transaksi pada periode ini.',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.5),
              1: pw.FlexColumnWidth(1.6),
              2: pw.FlexColumnWidth(1.8),
              3: pw.FlexColumnWidth(2),
              4: pw.FlexColumnWidth(1.5),
              5: pw.FlexColumnWidth(1.8),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _cell('No', bold: true),
                  _cell('Tanggal', bold: true),
                  _cell('Kode Pesanan', bold: true),
                  _cell('Pelanggan', bold: true),
                  _cell('Metode', bold: true),
                  _cell('Jumlah', bold: true, alignRight: true),
                ],
              ),
              for (var i = 0; i < payments.length; i++)
                pw.TableRow(
                  children: [
                    _cell('${i + 1}'),
                    _cell(
                      formatTanggalSingkat(
                        payments[i].paidAt ?? payments[i].createdAt,
                      ),
                    ),
                    _cell(
                      ordersById[payments[i].orderId]?.orderCode ??
                          payments[i].orderId.substring(0, 8).toUpperCase(),
                    ),
                    _cell(ordersById[payments[i].orderId]?.customerName ?? '-'),
                    _cell(_paymentMethodLabel(payments[i].method)),
                    _cell(formatRupiah(payments[i].amount), alignRight: true),
                  ],
                ),
            ],
          ),
        pw.SizedBox(height: 14),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Total Pendapatan: ${formatRupiah(total)}',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  return doc.save();
}
