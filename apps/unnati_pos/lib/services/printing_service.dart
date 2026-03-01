// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS
//
// ESC/POS Thermal Printing Service
// Supports 58mm and 80mm printers via USB (Windows/Android) and Bluetooth (Android).

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';

import 'vat_service.dart';
import '../data/repositories/sale_repository.dart';
import '../data/local/database.dart';

enum PrinterConnection { bluetooth, usb }
enum PaperWidth { mm58, mm80 }

/// UnnatiPrintingService handles ESC/POS thermal receipt printing.
class UnnatiPrintingService {
  final PaperWidth paperWidth;
  final String shopName;
  final String shopAddress;
  final String shopPhone;
  final String? panNumber;
  final String? vatNumber;

  UnnatiPrintingService({
    required this.shopName,
    required this.shopAddress,
    required this.shopPhone,
    this.panNumber,
    this.vatNumber,
    this.paperWidth = PaperWidth.mm80,
  });

  /// Build ESC/POS byte buffer for a completed sale receipt.
  Future<List<int>> buildReceipt({
    required SalesTableData sale,
    required List<SaleItemsTableData> items,
    required String fiscalYear,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(
      paperWidth == PaperWidth.mm80 ? PaperSize.mm80 : PaperSize.mm58,
      profile,
    );

    List<int> bytes = [];

    // ── Header ────────────────────────────────────────────────────────────
    bytes += generator.setGlobalCodeTable('CP1252');
    bytes += generator.text(
      shopName.toUpperCase(),
      styles: const PosStyles(
        bold: true,
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(shopAddress, styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Ph: $shopPhone', styles: const PosStyles(align: PosAlign.center));

    if (panNumber != null) {
      bytes += generator.text('PAN: $panNumber', styles: const PosStyles(align: PosAlign.center));
    }
    if (vatNumber != null) {
      bytes += generator.text('VAT: $vatNumber', styles: const PosStyles(align: PosAlign.center));
    }

    bytes += generator.hr(ch: '=');

    // ── Bill Info ─────────────────────────────────────────────────────────
    bytes += generator.row([
      PosColumn(text: 'Bill No:', width: 5, styles: const PosStyles(bold: true)),
      PosColumn(text: sale.billNumber, width: 7),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Date:', width: 5, styles: const PosStyles(bold: true)),
      PosColumn(text: _formatDate(sale.soldAt), width: 7),
    ]);
    bytes += generator.row([
      PosColumn(text: 'FY:', width: 5, styles: const PosStyles(bold: true)),
      PosColumn(text: fiscalYear, width: 7),
    ]);

    if (sale.customerId != null && sale.customerPan != null) {
      bytes += generator.row([
        PosColumn(text: 'Cust PAN:', width: 5, styles: const PosStyles(bold: true)),
        PosColumn(text: sale.customerPan!, width: 7),
      ]);
    }

    bytes += generator.hr();

    // ── Items ─────────────────────────────────────────────────────────────
    bytes += generator.row([
      PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true, underline: true)),
      PosColumn(text: 'Qty', width: 2, styles: const PosStyles(bold: true, underline: true, align: PosAlign.right)),
      PosColumn(text: 'Price', width: 4, styles: const PosStyles(bold: true, underline: true, align: PosAlign.right)),
    ]);

    for (final item in items) {
      bytes += generator.row([
        PosColumn(text: _truncate(item.productName, 18), width: 6),
        PosColumn(text: item.qty.toStringAsFixed(2), width: 2, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: VatService.formatNPR(item.lineTotal), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
      if (item.isVatApplicable) {
        bytes += generator.text(
          '  (VAT applicable)',
          styles: const PosStyles(fontType: PosFontType.fontB),
        );
      }
    }

    bytes += generator.hr();

    // ── Totals ────────────────────────────────────────────────────────────
    bytes += generator.row([
      PosColumn(text: 'Sub Total:', width: 7),
      PosColumn(text: VatService.formatNPR(sale.subTotal), width: 5, styles: const PosStyles(align: PosAlign.right)),
    ]);

    if (sale.discountAmt > 0) {
      bytes += generator.row([
        PosColumn(text: 'Discount:', width: 7),
        PosColumn(text: '- ${VatService.formatNPR(sale.discountAmt)}', width: 5, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.row([
      PosColumn(text: 'Taxable Amt:', width: 7),
      PosColumn(text: VatService.formatNPR(sale.taxableAmount), width: 5, styles: const PosStyles(align: PosAlign.right)),
    ]);

    bytes += generator.row([
      PosColumn(text: 'VAT (13%):', width: 7),
      PosColumn(text: VatService.formatNPR(sale.vatAmount), width: 5, styles: const PosStyles(align: PosAlign.right)),
    ]);

    bytes += generator.hr(ch: '=');

    bytes += generator.row([
      PosColumn(text: 'GRAND TOTAL:', width: 7, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(text: VatService.formatNPR(sale.grandTotal), width: 5,
          styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2)),
    ]);

    bytes += generator.row([
      PosColumn(text: 'Paid:', width: 7),
      PosColumn(text: VatService.formatNPR(sale.paidAmount), width: 5, styles: const PosStyles(align: PosAlign.right)),
    ]);

    if (sale.changeAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Change:', width: 7),
        PosColumn(text: VatService.formatNPR(sale.changeAmount), width: 5,
            styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
    }

    bytes += generator.hr(ch: '=');

    // ── Footer ────────────────────────────────────────────────────────────
    bytes += generator.text(
      'Thank you for your purchase!',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      'Powered by Unnati Retail OS',
      styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB),
    );
    bytes += generator.text(
      'Walsong Group \u00a9 2026',
      styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB),
    );

    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _truncate(String text, int maxLen) {
    return text.length > maxLen ? '${text.substring(0, maxLen - 1)}.' : text;
  }
}
