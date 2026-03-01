// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../../data/local/database.dart';

class TaxReportService {
  final AppDatabase _db;

  TaxReportService(this._db);

  /// Generates Annexure 13 (Sales Book) for IRD Nepal
  /// Required columns: Date, Invoice No, Buyer Name, PAN, Total Sales, Taxable, VAT Amount
  Future<void> generateAnnexure13(int year, int month) async {
    // 1. Fetch Sales Data for the month
    // In production, we'd use Drift expressions to filter by year/month accurately.
    // Simplifying fetch-all memory filter for this demo.
    final allSales = await _db.select(_db.salesTable).get();
    
    final filteredSales = allSales.where((s) {
      final nepaliDate = NepaliDateTime.fromDateTime(s.soldAt);
      return nepaliDate.year == year && nepaliDate.month == month;
    }).toList();

    // 2. Build PDF Document
    final doc = pw.Document();
    final NepaliDateTime generatedAt = NepaliDateTime.now();

    final List<List<dynamic>> tableData = [];
    tableData.add(['Miti (Date)', 'Invoice No.', 'Buyer Name', 'Buyer PAN', 'Total Sales', 'Taxable Amt', 'VAT (13%)']);

    double sumTotal = 0;
    double sumTaxable = 0;
    double sumVat = 0;

    for (var sale in filteredSales) {
      if (sale.status == 'draft' || sale.status == 'held') continue;

      final saleDate = NepaliDateFormat('yyyy-MM-dd').format(NepaliDateTime.fromDateTime(sale.soldAt));
      
      sumTotal += sale.grandTotal;
      sumTaxable += sale.taxableAmount;
      sumVat += sale.vatAmount;

      tableData.add([
        saleDate,
        "${sale.billNumber} ${sale.status == 'cancelled' ? '(CANCELLED)' : ''}",
        sale.status == 'cancelled' ? '-' : 'Walk-in / Cash', // Simplified buyer name
        sale.customerPan ?? '-',
        sale.status == 'cancelled' ? '0.00' : sale.grandTotal.toStringAsFixed(2),
        sale.status == 'cancelled' ? '0.00' : sale.taxableAmount.toStringAsFixed(2),
        sale.status == 'cancelled' ? '0.00' : sale.vatAmount.toStringAsFixed(2),
      ]);
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('UNNATI RETAIL OS', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                    pw.Text('Hardware Shop Pro Nepal'),
                    pw.SizedBox(height: 12),
                    pw.Text('ANNEXURE 13: SALES BOOK (Bikri Khata)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  ]
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Month: $year-$month (B.S.)'),
                    pw.Text('Generated On: ${NepaliDateFormat('yyyy-MM-dd HH:mm').format(generatedAt)}'),
                  ]
                )
              ]
            ),
            pw.SizedBox(height: 24),
            pw.TableHelper.fromTextArray(
              context: context,
              data: tableData,
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Total Taxable: Rs. ${sumTaxable.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Total VAT (Output Tax): Rs. ${sumVat.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                      pw.Text('Grand Total Sales: Rs. ${sumTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ]
                  )
                )
              ]
            )
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Annexure_13_${year}_$month',
    );
  }
}
