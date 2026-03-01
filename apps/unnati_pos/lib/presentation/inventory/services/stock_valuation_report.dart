// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../data/local/database.dart';

class StockValuationReport {
  final AppDatabase _db;

  StockValuationReport(this._db);

  /// Generates the "Annexure 10" Monthly Stock Valuation Report (Closing Stock)
  /// and automatically opens the platform's native PDF print/save preview.
  Future<void> generateAndPreview() async {
    // 1. Fetch live stock data
    final products = await _db.select(_db.productsTable).get();

    // 2. Calculate totals
    double totalValuation = 0;
    final List<List<dynamic>> tableData = [];

    // Header Row
    tableData.add(['SKU', 'Product Name', 'Unit', 'Stock Qty', 'Cost Price (Rs)', 'Total Value (Rs)']);

    for (var p in products) {
      if (p.stockQty <= 0) continue; // Only value on-hand stock

      final value = p.stockQty * p.costPrice;
      totalValuation += value;

      tableData.add([
        p.sku,
        p.name,
        'pc', // Default display unit for report simplicity
        p.stockQty.toStringAsFixed(2),
        p.costPrice.toStringAsFixed(2),
        value.toStringAsFixed(2),
      ]);
    }

    final doc = pw.Document();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 3. Build PDF Document
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('UNNATI RETAIL OS', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                    pw.Text('Hardware Shop Pro Nepal'),
                    pw.SizedBox(height: 16),
                    pw.Text('MONTHLY STOCK VALUATION REPORT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Closing Stock Annexure (IRD Format)'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Date: $today'),
                    pw.Text('Fiscal Year: 2081/82'),
                  ]
                )
              ]
            ),
            pw.SizedBox(height: 24),

            // Data Table
            pw.TableHelper.fromTextArray(
              context: context,
              data: tableData,
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellAlignment: pw.Alignment.centerRight,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
              },
            ),

            pw.SizedBox(height: 16),

            // Grand Total Footer
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Text('Total Stock Valuation: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      pw.Text('Rs. ${totalValuation.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.green800)),
                    ]
                  )
                )
              ]
            ),
          ];
        },
      ),
    );

    // 4. Trigger print/preview native dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Stock_Valuation_Report_$today',
    );
  }
}
