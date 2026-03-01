// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS
// Founder: Sangam Baral
//
// SaleRepository — The crown jewel of the Local-First architecture.
//
// Every sale operation:
//   1. Writes atomically to local SQLite (zero network latency)
//   2. Enqueues CDC delta in the sync_queue table (same transaction)
//   3. Returns immediately — the UI never waits for the network
//
// The SyncService picks up the queue in the background.

import 'dart:convert';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/database.dart';
import '../../services/vat_service.dart';

const _uuid = Uuid();

/// Represents a bill being actively built at the counter.
class BillDraft {
  final String id;
  final String staffId;
  final String deviceId;
  final String fiscalYear;
  String? customerId;
  String? customerPan;
  List<BillLineItem> items;
  String paymentMethod;
  String notes;

  BillDraft({
    required this.id,
    required this.staffId,
    required this.deviceId,
    required this.fiscalYear,
    this.customerId,
    this.customerPan,
    List<BillLineItem>? items,
    this.paymentMethod = 'cash',
    this.notes = '',
  }) : items = items ?? [];

  factory BillDraft.create(String staffId, String deviceId) {
    return BillDraft(
      id: _uuid.v4(),
      staffId: staffId,
      deviceId: deviceId,
      fiscalYear: VatService.currentFiscalYear(),
    );
  }
}

class BillLineItem {
  final String productId;
  final String productName;
  final String unitId;
  final double qty;
  final double unitPrice;
  final double discountPct;
  final double costPrice;
  final bool isVatApplicable;

  double get lineTotal {
    final discounted = unitPrice * (1 - discountPct / 100);
    return qty * discounted;
  }

  BillLineItem({
    required this.productId,
    required this.productName,
    required this.unitId,
    required this.qty,
    required this.unitPrice,
    this.discountPct = 0,
    this.costPrice = 0,
    this.isVatApplicable = false,
  });
}

/// SaleRepository — all methods write to SQLite first, enqueue sync second.
class SaleRepository {
  final AppDatabase _db;

  SaleRepository(this._db);

  // ─── Create & Complete Sale ──────────────────────────────────────────────

  /// [createSale] is the atomic core of the billing engine.
  ///
  /// Wraps the entire operation in a Drift transaction:
  ///   - Insert Sale row
  ///   - Insert all SaleItem rows
  ///   - Deduct stock from Products
  ///   - Enqueue CDC delta for the sync engine
  ///
  /// Returns the completed [SalesTableData].
  Future<SalesTableData> createSale({
    required BillDraft draft,
    required double paidAmount,
  }) async {
    final vatResult = VatService.calculate(draft.items);
    final now = DateTime.now().toUtc();
    final billNumber = _generateBillNumber(now);
    final grandTotal = vatResult.grandTotal;
    final changeAmount = paidAmount - grandTotal;

    // Calculate net profit (total lineTotal - total costPrice)
    double totalCost = 0;
    for (final item in draft.items) {
      totalCost += item.qty * item.costPrice;
    }
    final netProfit = vatResult.grandTotal - totalCost;

    return _db.transaction(() async {
      // ── 1. Insert Sale ───────────────────────────────────────────────────
      final sale = SalesTableCompanion.insert(
        id: _uuid.v4(),
        billNumber: billNumber,
        staffId: draft.staffId,
        customerId: Value(draft.customerId),
        status: 'completed',
        paymentMethod: draft.paymentMethod,
        subTotal: vatResult.subTotal,
        discountAmt: vatResult.discountAmt,
        taxableAmount: vatResult.taxableAmount,
        vatAmount: vatResult.vatAmount,
        grandTotal: grandTotal,
        paidAmount: paidAmount,
        changeAmount: changeAmount > 0 ? changeAmount : 0,
        netProfit: netProfit,
        customerPan: Value(draft.customerPan),
        fiscalYear: draft.fiscalYear,
        fonepayQrRef: const Value(null),
        notes: Value(draft.notes.isNotEmpty ? draft.notes : null),
        deviceId: draft.deviceId,
        soldAt: now,
        updatedAt: now,
        createdAt: now,
      );

      final saleRow = await _db.into(_db.salesTable).insertReturning(sale);

      // ── 2. Insert Sale Items & Deduct Stock ───────────────────────────────
      for (final item in draft.items) {
        // Insert line item
        await _db.into(_db.saleItemsTable).insert(
          SaleItemsTableCompanion.insert(
            id: _uuid.v4(),
            saleId: saleRow.id,
            productId: item.productId,
            productName: item.productName,
            qty: item.qty,
            unitId: item.unitId,
            unitPrice: item.unitPrice,
            discountPct: item.discountPct,
            isVatApplicable: item.isVatApplicable,
            lineTotal: item.lineTotal,
            costPrice: item.costPrice,
            createdAt: now,
          ),
        );

        // Deduct stock (atomic with the sale)
        await (_db.update(_db.productsTable)
              ..where((p) => p.id.equals(item.productId)))
            .write(ProductsTableCompanion(
          stockQty: Value(
            (await (_db.select(_db.productsTable)
                      ..where((p) => p.id.equals(item.productId)))
                    .getSingle())
                .stockQty -
                item.qty,
          ),
          updatedAt: Value(now),
        ));
      }

      // ── 3. Enqueue CDC Delta ───────────────────────────────────────────────
      await _enqueueDelta(
        deviceId: draft.deviceId,
        tableName: 'sales',
        recordId: saleRow.id,
        operation: 'INSERT',
        payload: _saleToJson(saleRow, draft.items),
      );

      return saleRow;
    });
  }

  // ─── Hold Bill ───────────────────────────────────────────────────────────

  /// [holdBill] saves the current draft as "held" so the cashier can
  /// serve the next customer. The held bill can be resumed at any time.
  Future<SalesTableData> holdBill(BillDraft draft) async {
    final now = DateTime.now().toUtc();
    final vatResult = VatService.calculate(draft.items);

    return _db.transaction(() async {
      final sale = SalesTableCompanion.insert(
        id: draft.id,
        billNumber: 'HOLD-${draft.id.substring(0, 8).toUpperCase()}',
        staffId: draft.staffId,
        customerId: Value(draft.customerId),
        status: 'held',
        paymentMethod: draft.paymentMethod,
        subTotal: vatResult.subTotal,
        discountAmt: vatResult.discountAmt,
        taxableAmount: vatResult.taxableAmount,
        vatAmount: vatResult.vatAmount,
        grandTotal: vatResult.grandTotal,
        paidAmount: 0,
        changeAmount: 0,
        netProfit: 0,
        customerPan: Value(draft.customerPan),
        fiscalYear: draft.fiscalYear,
        fonepayQrRef: const Value(null),
        notes: Value('HELD BILL'),
        deviceId: draft.deviceId,
        soldAt: now,
        updatedAt: now,
        createdAt: now,
      );

      // Upsert (in case this bill was already held before)
      await _db.into(_db.salesTable).insertOnConflictUpdate(sale);

      // Store line items for resume
      for (final item in draft.items) {
        await _db.into(_db.saleItemsTable).insertOnConflictUpdate(
          SaleItemsTableCompanion.insert(
            id: '${draft.id}-${item.productId}'.hashCode.toString(),
            saleId: draft.id,
            productId: item.productId,
            productName: item.productName,
            qty: item.qty,
            unitId: item.unitId,
            unitPrice: item.unitPrice,
            discountPct: item.discountPct,
            isVatApplicable: item.isVatApplicable,
            lineTotal: item.lineTotal,
            costPrice: item.costPrice,
            createdAt: now,
          ),
        );
      }

      return (_db.select(_db.salesTable)
            ..where((s) => s.id.equals(draft.id)))
          .getSingle();
    });
  }

  /// Get all currently held bills (for the Hold Bill panel).
  Future<List<SalesTableData>> getHeldBills() {
    return (_db.select(_db.salesTable)..where((s) => s.status.equals('held')))
        .get();
  }

  /// Resume a held bill by loading its items back into a [BillDraft].
  Future<BillDraft> resumeHeldBill(String saleId, String staffId, String deviceId) async {
    final sale = await (_db.select(_db.salesTable)
          ..where((s) => s.id.equals(saleId)))
        .getSingle();

    final items = await (_db.select(_db.saleItemsTable)
          ..where((si) => si.saleId.equals(saleId)))
        .get();

    return BillDraft(
      id: sale.id,
      staffId: staffId,
      deviceId: deviceId,
      fiscalYear: sale.fiscalYear,
      customerId: sale.customerId,
      customerPan: sale.customerPan,
      paymentMethod: sale.paymentMethod,
      items: items
          .map((si) => BillLineItem(
                productId: si.productId,
                productName: si.productName,
                unitId: si.unitId,
                qty: si.qty,
                unitPrice: si.unitPrice,
                discountPct: si.discountPct,
                costPrice: si.costPrice,
                isVatApplicable: si.isVatApplicable,
              ))
          .toList(),
    );
  }

  // ─── Queries ─────────────────────────────────────────────────────────────

  Future<List<SalesTableData>> getTodaysSales() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    return (_db.select(_db.salesTable)
          ..where((s) =>
              s.soldAt.isBiggerOrEqualValue(start) &
              s.soldAt.isSmallerThanValue(end) &
              s.status.equals('completed')))
        .get();
  }

  Future<SalesTableData?> getSaleById(String id) {
    return (_db.select(_db.salesTable)..where((s) => s.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<SaleItemsTableData>> getSaleItems(String saleId) {
    return (_db.select(_db.saleItemsTable)
          ..where((si) => si.saleId.equals(saleId)))
        .get();
  }

  // ─── CDC Delta Enqueue ───────────────────────────────────────────────────

  Future<void> _enqueueDelta({
    required String deviceId,
    required String tableName,
    required String recordId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final now = DateTime.now().toUtc();
    await _db.into(_db.syncQueueTable).insert(
      SyncQueueTableCompanion.insert(
        id: _uuid.v4(),
        deviceId: deviceId,
        tableName_: tableName,
        recordId: recordId,
        operation: operation,
        payload: jsonEncode(payload),
        localSeq: now.microsecondsSinceEpoch,
        status: const Value('pending'),
        createdAt: now,
      ),
    );
  }

  Map<String, dynamic> _saleToJson(
      SalesTableData sale, List<BillLineItem> items) {
    return {
      'id': sale.id,
      'bill_number': sale.billNumber,
      'staff_id': sale.staffId,
      'customer_id': sale.customerId,
      'status': sale.status,
      'payment_method': sale.paymentMethod,
      'sub_total': sale.subTotal,
      'discount_amt': sale.discountAmt,
      'taxable_amount': sale.taxableAmount,
      'vat_amount': sale.vatAmount,
      'grand_total': sale.grandTotal,
      'paid_amount': sale.paidAmount,
      'change_amount': sale.changeAmount,
      'net_profit': sale.netProfit,
      'customer_pan': sale.customerPan,
      'fiscal_year': sale.fiscalYear,
      'notes': sale.notes,
      'device_id': sale.deviceId,
      'sold_at': sale.soldAt.toIso8601String(),
      'updated_at': sale.updatedAt.toIso8601String(),
      'created_at': sale.createdAt.toIso8601String(),
      'items': items
          .map((i) => {
                'product_id': i.productId,
                'product_name': i.productName,
                'qty': i.qty,
                'unit_price': i.unitPrice,
                'line_total': i.lineTotal,
              })
          .toList(),
    };
  }

  /// Generate bill number: INV-YYMM-NNNNN (local, sync with server later)
  String _generateBillNumber(DateTime now) {
    final ts = now.millisecondsSinceEpoch % 100000;
    final yymm =
        '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}';
    return 'INV-$yymm-${ts.toString().padLeft(5, '0')}';
  }
}
