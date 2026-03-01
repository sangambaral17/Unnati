// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS
// Founder: Sangam Baral
//
// ─────────────────────────────────────────────────────────────────────────────
//  SalesService — The Retail Engine
// ─────────────────────────────────────────────────────────────────────────────
//
//  This is the core business-logic layer for all sales operations.
//  It sits between the UI and the Drift database, enforcing:
//
//    1. Nepal VAT (13%) calculation on taxable items only.
//    2. Atomic stock subtraction (inventory deducted in the same SQLite tx).
//    3. CDC sync enqueue (every sale produces a sync_queue entry).
//    4. Unit conversion awareness ("Buy in Box, Sell in Pieces").
//
//  Architecture Note:
//  ┌─────────────────────────────────────────────────────────────────────────┐
//  │  UI Layer (Riverpod)                                                   │
//  │       │                                                                │
//  │       ▼                                                                │
//  │  SalesService   ← You are here. Pure business logic, no widgets.       │
//  │       │                                                                │
//  │       ▼                                                                │
//  │  AppDatabase (Drift / SQLite)   ← Local source of truth.               │
//  │       │                                                                │
//  │       ▼ (background)                                                   │
//  │  SyncService → Go Backend → PostgreSQL  ← Home server analytics.       │
//  └─────────────────────────────────────────────────────────────────────────┘
//
//  INVARIANT: All writes to SQLite are wrapped in a single Drift transaction.
//  If any step fails (e.g., insufficient stock), the ENTIRE sale rolls back.
//  The UI never sees a partial sale.
//
//  INVARIANT: SyncQueue entries are written INSIDE the same transaction.
//  If the transaction commits, the sync entry exists. No orphaned syncs.

import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../data/local/database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/// Nepal's standard VAT rate: 13%.
/// Reference: IRD Nepal, VAT Act 2052, Section 16(1).
const double kNepalVATRate = 0.13;

const _uuid = Uuid();

// ─────────────────────────────────────────────────────────────────────────────
// Data Transfer Objects (DTOs)
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a single line item input from the billing screen.
///
/// This is a pure DTO — no database dependency, no Drift companion.
/// The SalesService converts this into the proper Drift inserts.
class SaleLineInput {
  final String productId;
  final String productName;
  final String unitId;       // The selling unit (e.g., Piece, Meter)
  final double quantity;
  final double unitPrice;    // Selling price per unit
  final double costPrice;    // Cost price per unit (hidden from cashier UI)
  final double discountPct;  // Line-level discount percentage (0–100)
  final bool isVatApplicable;

  const SaleLineInput({
    required this.productId,
    required this.productName,
    required this.unitId,
    required this.quantity,
    required this.unitPrice,
    this.costPrice = 0,
    this.discountPct = 0,
    this.isVatApplicable = false,
  });

  /// Line total = qty × unitPrice × (1 - discount%).
  /// This is the BEFORE-VAT amount.
  double get lineTotal {
    final discountedPrice = unitPrice * (1 - discountPct / 100);
    return quantity * discountedPrice;
  }

  /// Cost of goods for this line = qty × costPrice.
  double get lineCost => quantity * costPrice;
}

/// Complete input for creating a sale. Passed from the billing screen.
class CreateSaleInput {
  final String staffId;
  final String deviceId;
  final String? customerId;
  final String? customerPan;
  final String paymentMethod; // cash | fonepay | credit | transfer
  final List<SaleLineInput> items;
  final double paidAmount;
  final String? notes;

  const CreateSaleInput({
    required this.staffId,
    required this.deviceId,
    required this.items,
    required this.paidAmount,
    this.customerId,
    this.customerPan,
    this.paymentMethod = 'cash',
    this.notes,
  });
}

/// Computed output after VAT calculation.
/// Returned to the UI for display and receipt printing.
class SaleResult {
  final String saleId;
  final String billNumber;
  final double subTotal;       // Sum of all line totals (before VAT)
  final double taxableAmount;  // Sum of VAT-applicable line totals
  final double vatAmount;      // taxableAmount × 13%
  final double grandTotal;     // subTotal + vatAmount
  final double paidAmount;
  final double changeAmount;
  final double netProfit;      // (grandTotal - totalCost) — owner eyes only
  final String fiscalYear;
  final DateTime timestamp;

  const SaleResult({
    required this.saleId,
    required this.billNumber,
    required this.subTotal,
    required this.taxableAmount,
    required this.vatAmount,
    required this.grandTotal,
    required this.paidAmount,
    required this.changeAmount,
    required this.netProfit,
    required this.fiscalYear,
    required this.timestamp,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SalesService
// ─────────────────────────────────────────────────────────────────────────────

/// SalesService is the single entry point for all sale transactions.
///
/// It guarantees ACID compliance at the SQLite level:
///   - [completeSale] wraps ALL mutations in a single Drift [transaction].
///   - Stock is decremented atomically.
///   - A CDC sync_queue entry is enqueued in the same transaction.
///   - If any step fails, the entire transaction rolls back.
///
/// Usage from the billing Riverpod provider:
/// ```dart
/// final salesService = SalesService(ref.watch(databaseProvider));
/// final result = await salesService.completeSale(input);
/// // result.billNumber → "INV-2603-00042"
/// // result.grandTotal → 5650.00
/// // Show receipt...
/// ```
class SalesService {
  final AppDatabase _db;

  SalesService(this._db);

  // ─── Primary Sale Operation ────────────────────────────────────────────

  /// Completes a sale in a single atomic transaction.
  ///
  /// Steps executed inside ONE Drift transaction:
  ///   1. Calculate VAT (13% on taxable items only).
  ///   2. Generate a local bill number.
  ///   3. INSERT the Sale header row.
  ///   4. INSERT each SaleItem line row.
  ///   5. SUBTRACT stock from each Product row.
  ///   6. ENQUEUE a CDC sync_queue entry for the Go backend.
  ///
  /// Returns a [SaleResult] with computed totals for receipt display.
  ///
  /// Throws [InsufficientStockException] if any product has insufficient stock.
  /// The entire transaction is rolled back — nothing is committed.
  Future<SaleResult> completeSale(CreateSaleInput input) async {
    if (input.items.isEmpty) {
      throw ArgumentError('Cannot complete a sale with zero items.');
    }

    // ── Step 1: Compute VAT and totals ──────────────────────────────────
    final vatBreakdown = _computeVAT(input.items);
    final now = DateTime.now().toUtc();
    final saleId = _uuid.v4();
    final billNumber = _generateBillNumber(now);
    final fiscalYear = _currentNepaliFiscalYear();
    final changeAmount = input.paidAmount - vatBreakdown.grandTotal;

    // ── Step 2: Atomic transaction ──────────────────────────────────────
    await _db.transaction(() async {
      // ── 2a. Insert Sale header ────────────────────────────────────────
      await _db.into(_db.salesTable).insert(
        SalesTableCompanion.insert(
          id: saleId,
          billNumber: billNumber,
          staffId: input.staffId,
          customerId: Value(input.customerId),
          status: 'completed',
          paymentMethod: input.paymentMethod,
          subTotal: vatBreakdown.subTotal,
          discountAmt: 0,
          taxableAmount: vatBreakdown.taxableAmount,
          vatAmount: vatBreakdown.vatAmount,
          grandTotal: vatBreakdown.grandTotal,
          paidAmount: input.paidAmount,
          changeAmount: changeAmount > 0 ? changeAmount : 0,
          netProfit: vatBreakdown.netProfit,
          customerPan: Value(input.customerPan),
          fiscalYear: fiscalYear,
          fonepayQrRef: const Value(null),
          notes: Value(input.notes),
          deviceId: input.deviceId,
          soldAt: now,
          updatedAt: now,
          createdAt: now,
        ),
      );

      // ── 2b. Insert line items and deduct stock ────────────────────────
      for (final item in input.items) {
        // Insert the sale_items row
        await _db.into(_db.saleItemsTable).insert(
          SaleItemsTableCompanion.insert(
            id: _uuid.v4(),
            saleId: saleId,
            productId: item.productId,
            productName: item.productName,
            qty: item.quantity,
            unitId: item.unitId,
            unitPrice: item.unitPrice,
            discountPct: item.discountPct,
            isVatApplicable: item.isVatApplicable,
            lineTotal: item.lineTotal,
            costPrice: item.costPrice,
            createdAt: now,
          ),
        );

        // Subtract stock atomically
        // Read current stock → check sufficiency → write new stock
        final product = await (_db.select(_db.productsTable)
              ..where((p) => p.id.equals(item.productId)))
            .getSingle();

        if (product.stockQty < item.quantity) {
          throw InsufficientStockException(
            productName: item.productName,
            available: product.stockQty,
            requested: item.quantity,
          );
        }

        await (_db.update(_db.productsTable)
              ..where((p) => p.id.equals(item.productId)))
            .write(ProductsTableCompanion(
          stockQty: Value(product.stockQty - item.quantity),
          updatedAt: Value(now),
        ));
      }

      // ── 2c. Enqueue CDC sync delta ────────────────────────────────────
      // This entry will be picked up by SyncService and pushed to the
      // Go backend. It remains 'pending' until delivery is confirmed.
      await _db.into(_db.syncQueueTable).insert(
        SyncQueueTableCompanion.insert(
          id: _uuid.v4(),
          deviceId: input.deviceId,
          tableName_: 'sales',
          recordId: saleId,
          operation: 'INSERT',
          payload: jsonEncode(_buildSyncPayload(
            saleId: saleId,
            billNumber: billNumber,
            input: input,
            vatBreakdown: vatBreakdown,
            fiscalYear: fiscalYear,
            timestamp: now,
          )),
          localSeq: now.microsecondsSinceEpoch,
          status: const Value('pending'),
          createdAt: now,
        ),
      );

      // Also enqueue each sale_item (so the Go backend can deduct
      // server-side stock and feed the analytics pipeline)
      for (final item in input.items) {
        await _db.into(_db.syncQueueTable).insert(
          SyncQueueTableCompanion.insert(
            id: _uuid.v4(),
            deviceId: input.deviceId,
            tableName_: 'sale_items',
            recordId: _uuid.v4(), // sale_item PK
            operation: 'INSERT',
            payload: jsonEncode({
              'sale_id': saleId,
              'product_id': item.productId,
              'product_name': item.productName,
              'qty': item.quantity,
              'unit_id': item.unitId,
              'unit_price': item.unitPrice,
              'discount_pct': item.discountPct,
              'is_vat_applicable': item.isVatApplicable,
              'line_total': item.lineTotal,
              'cost_price': item.costPrice,
            }),
            localSeq: now.microsecondsSinceEpoch + 1,
            status: const Value('pending'),
            createdAt: now,
          ),
        );
      }
    });

    // ── Step 3: Return computed result to the UI ─────────────────────────
    return SaleResult(
      saleId: saleId,
      billNumber: billNumber,
      subTotal: vatBreakdown.subTotal,
      taxableAmount: vatBreakdown.taxableAmount,
      vatAmount: vatBreakdown.vatAmount,
      grandTotal: vatBreakdown.grandTotal,
      paidAmount: input.paidAmount,
      changeAmount: changeAmount > 0 ? changeAmount : 0,
      netProfit: vatBreakdown.netProfit,
      fiscalYear: fiscalYear,
      timestamp: now,
    );
  }

  // ─── Unit Conversion ──────────────────────────────────────────────────

  /// Converts a quantity from one unit to another for a given product.
  ///
  /// Example: A "Box" of nails contains 100 "Pieces".
  ///   await convertUnit('nail-product-id', 2.0, 'box-id', 'piece-id')
  ///   → 200.0
  ///
  /// Returns null if no conversion rule is defined.
  Future<double?> convertUnit(
    String productId,
    double qty,
    String fromUnitId,
    String toUnitId,
  ) async {
    if (fromUnitId == toUnitId) return qty;

    final conversion = await (_db.select(_db.unitConversionsTable)
          ..where((c) =>
              c.productId.equals(productId) &
              c.fromUnitId.equals(fromUnitId) &
              c.toUnitId.equals(toUnitId)))
        .getSingleOrNull();

    if (conversion != null) {
      return qty * conversion.factor;
    }

    // Try reverse conversion: to → from
    final reverse = await (_db.select(_db.unitConversionsTable)
          ..where((c) =>
              c.productId.equals(productId) &
              c.fromUnitId.equals(toUnitId) &
              c.toUnitId.equals(fromUnitId)))
        .getSingleOrNull();

    if (reverse != null && reverse.factor != 0) {
      return qty / reverse.factor;
    }

    return null; // No conversion rule found
  }

  // ─── VAT Calculation ──────────────────────────────────────────────────

  /// Computes the Nepal 13% VAT breakdown.
  ///
  /// Rules:
  ///   - Only items with [isVatApplicable == true] contribute to taxable amount.
  ///   - VAT = taxableAmount × 0.13.
  ///   - Grand total = subTotal + VAT.
  ///   - Net profit = grand total − total COGS (cost of goods sold).
  _VATBreakdown _computeVAT(List<SaleLineInput> items) {
    double taxableAmount = 0;
    double nonTaxableAmount = 0;
    double totalCost = 0;

    for (final item in items) {
      if (item.isVatApplicable) {
        taxableAmount += item.lineTotal;
      } else {
        nonTaxableAmount += item.lineTotal;
      }
      totalCost += item.lineCost;
    }

    final subTotal = taxableAmount + nonTaxableAmount;
    final vatAmount = _round2(taxableAmount * kNepalVATRate);
    final grandTotal = _round2(subTotal + vatAmount);
    final netProfit = _round2(grandTotal - totalCost);

    return _VATBreakdown(
      subTotal: subTotal,
      taxableAmount: taxableAmount,
      vatAmount: vatAmount,
      grandTotal: grandTotal,
      netProfit: netProfit,
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────

  /// Generates a locally-unique bill number: INV-YYMM-NNNNN.
  /// On sync, the Go server may re-assign from its global sequence.
  String _generateBillNumber(DateTime now) {
    final ts = now.millisecondsSinceEpoch % 100000;
    final yy = now.year.toString().substring(2);
    final mm = now.month.toString().padLeft(2, '0');
    return 'INV-$yy$mm-${ts.toString().padLeft(5, '0')}';
  }

  /// Returns the current Nepali fiscal year string.
  /// Nepal's fiscal year runs from Shrawan 1 (~July 16) to Ashadh 31 (~July 15).
  /// BS year ≈ AD year + 57 (approximately).
  String _currentNepaliFiscalYear() {
    final now = DateTime.now();
    final bsOffset = 57;
    if (now.month >= 7 && now.day >= 16) {
      // After mid-July: new fiscal year
      return '${now.year + bsOffset - 1}/${(now.year + bsOffset).toString().substring(2)}';
    } else {
      return '${now.year + bsOffset - 2}/${(now.year + bsOffset - 1).toString().substring(2)}';
    }
  }

  /// Rounds to 2 decimal places (paisa precision for NPR).
  double _round2(double v) => (v * 100).round() / 100;

  /// Builds the JSON payload for the CDC sync_queue entry.
  Map<String, dynamic> _buildSyncPayload({
    required String saleId,
    required String billNumber,
    required CreateSaleInput input,
    required _VATBreakdown vatBreakdown,
    required String fiscalYear,
    required DateTime timestamp,
  }) {
    return {
      'id': saleId,
      'bill_number': billNumber,
      'staff_id': input.staffId,
      'customer_id': input.customerId,
      'status': 'completed',
      'payment_method': input.paymentMethod,
      'sub_total': vatBreakdown.subTotal,
      'discount_amt': 0,
      'taxable_amount': vatBreakdown.taxableAmount,
      'vat_amount': vatBreakdown.vatAmount,
      'grand_total': vatBreakdown.grandTotal,
      'paid_amount': input.paidAmount,
      'net_profit': vatBreakdown.netProfit,
      'customer_pan': input.customerPan,
      'fiscal_year': fiscalYear,
      'notes': input.notes,
      'device_id': input.deviceId,
      'sold_at': timestamp.toIso8601String(),
      'updated_at': timestamp.toIso8601String(),
      'created_at': timestamp.toIso8601String(),
      'items': input.items
          .map((i) => {
                'product_id': i.productId,
                'product_name': i.productName,
                'qty': i.quantity,
                'unit_id': i.unitId,
                'unit_price': i.unitPrice,
                'discount_pct': i.discountPct,
                'is_vat_applicable': i.isVatApplicable,
                'line_total': i.lineTotal,
                'cost_price': i.costPrice,
              })
          .toList(),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal Types
// ─────────────────────────────────────────────────────────────────────────────

/// Internal VAT computation result — not exposed outside this file.
class _VATBreakdown {
  final double subTotal;
  final double taxableAmount;
  final double vatAmount;
  final double grandTotal;
  final double netProfit;

  const _VATBreakdown({
    required this.subTotal,
    required this.taxableAmount,
    required this.vatAmount,
    required this.grandTotal,
    required this.netProfit,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Exceptions
// ─────────────────────────────────────────────────────────────────────────────

/// Thrown when a sale item requests more stock than is available.
/// Because this is inside a transaction, the entire sale is rolled back.
class InsufficientStockException implements Exception {
  final String productName;
  final double available;
  final double requested;

  const InsufficientStockException({
    required this.productName,
    required this.available,
    required this.requested,
  });

  @override
  String toString() =>
      'InsufficientStockException: "$productName" has $available units '
      'available but $requested were requested.';
}
