// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:intl/intl.dart';

import '../data/repositories/sale_repository.dart';

/// VAT rate for Nepal (13%)
const double kVATRate = 0.13;

class VatResult {
  final double subTotal;
  final double discountAmt;
  final double taxableAmount;
  final double vatAmount;
  final double grandTotal;

  const VatResult({
    required this.subTotal,
    required this.discountAmt,
    required this.taxableAmount,
    required this.vatAmount,
    required this.grandTotal,
  });
}

/// VatService — Nepal VAT/PAN compliant calculation engine.
///
/// VAT is calculated ONLY on items marked [isVatApplicable].
/// Non-VAT items are passed through at their discounted line total.
class VatService {
  /// Calculate VAT breakdown for a list of bill line items.
  static VatResult calculate(List<BillLineItem> items) {
    double taxableSubTotal = 0;
    double nonTaxableSubTotal = 0;

    for (final item in items) {
      if (item.isVatApplicable) {
        taxableSubTotal += item.lineTotal;
      } else {
        nonTaxableSubTotal += item.lineTotal;
      }
    }

    final subTotal = taxableSubTotal + nonTaxableSubTotal;
    final vatAmount = taxableSubTotal * kVATRate;
    final grandTotal = subTotal + vatAmount;

    return VatResult(
      subTotal: subTotal,
      discountAmt: 0, // Bill-level discount unused here; item-level used
      taxableAmount: taxableSubTotal,
      vatAmount: _round(vatAmount),
      grandTotal: _round(grandTotal),
    );
  }

  /// Apply an additional bill-level discount (percentage) and recalculate VAT.
  static VatResult calculateWithBillDiscount(
    List<BillLineItem> items,
    double billDiscountPct,
  ) {
    final base = calculate(items);
    final discountFraction = billDiscountPct / 100;
    final discount = base.subTotal * discountFraction;
    final discountedTaxable =
        base.taxableAmount * (1 - discountFraction);
    final vatAmount = discountedTaxable * kVATRate;
    final grandTotal = (base.subTotal - discount) + vatAmount;

    return VatResult(
      subTotal: base.subTotal,
      discountAmt: _round(discount),
      taxableAmount: _round(discountedTaxable),
      vatAmount: _round(vatAmount),
      grandTotal: _round(grandTotal),
    );
  }

  /// Format an amount in Nepali Rupees (NPR).
  static String formatNPR(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'ne_NP',
      symbol: 'Rs. ',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Returns the current Nepal fiscal year string (e.g., "2081/82").
  /// Nepal's fiscal year runs Shrawan 1 to Ashadh 31 (≈ mid-July to mid-July).
  static String currentFiscalYear() {
    final now = DateTime.now();
    // Approximate: fiscal year starts ~July 16
    final fiscalStart = DateTime(now.year, 7, 16);
    if (now.isBefore(fiscalStart)) {
      return '${now.year - 57}/${(now.year - 56).toString().substring(2)}';
    } else {
      return '${now.year - 56}/${(now.year - 55).toString().substring(2)}';
    }
  }

  static double _round(double v) => (v * 100).round() / 100;
}
