// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:drift/drift.dart';
import '../../data/local/database.dart';

class StockInInput {
  final String supplierId;
  final String staffId;
  final String deviceId;
  final String paymentMethod;
  final double paidAmount;
  final String notes;
  final List<StockInItem> items;

  StockInInput({
    required this.supplierId,
    required this.staffId,
    required this.deviceId,
    required this.paymentMethod,
    required this.paidAmount,
    this.notes = '',
    required this.items,
  });
}

class StockInItem {
  final String productId;
  final double receivedQty;
  final double newCostPrice;

  StockInItem({
    required this.productId,
    required this.receivedQty,
    required this.newCostPrice,
  });
}

class SupplierRepository {
  final AppDatabase _db;

  SupplierRepository(this._db);

  /// Executes a 'Stock In' transaction atomically.
  /// 1. Creates a Purchase Order.
  /// 2. Updates Product Stock Qty AND Cost Price.
  /// 3. Updates Supplier Payable ledger if it's a credit purchase.
  /// 4. Enqueues CDC sync.
  Future<String> processStockIn(StockInInput input) async {
    final poId = DateTime.now().millisecondsSinceEpoch.toString();
    final poNumber = 'PO-${DateTime.now().millisecondsSinceEpoch}';
    double totalAmount = 0;

    await _db.transaction(() async {
      final now = DateTime.now().toUtc();

      // 1. Process items, update stock and calculate total
      for (var item in input.items) {
        final product = await (_db.select(_db.productsTable)..where((p) => p.id.equals(item.productId))).getSingle();
        
        // Calculate weighted average cost price (simplified to just replacing for now, per retail norms locally)
        final double lineTotal = item.receivedQty * item.newCostPrice;
        totalAmount += lineTotal;

        // Update Stock and Cost Price
        await (_db.update(_db.productsTable)..where((p) => p.id.equals(item.productId))).write(
          ProductsTableCompanion(
            stockQty: Value(product.stockQty + item.receivedQty),
            costPrice: Value(item.newCostPrice),
            updatedAt: Value(now),
          )
        );

        // Map CDC for product update
        await _enqueueCDC('products', item.productId, 'UPDATE', {
          'id': item.productId,
          'stock_qty': product.stockQty + item.receivedQty,
          'cost_price': item.newCostPrice,
        }, input.deviceId);
      }

      // 2. Create Purchase Order
      await _db.into(_db.purchaseOrdersTable).insert(
        PurchaseOrdersTableCompanion.insert(
          id: poId,
          poNumber: poNumber,
          supplierId: input.supplierId,
          staffId: input.staffId,
          status: const Value('completed'),
          paymentMethod: Value(input.paymentMethod),
          totalAmount: Value(totalAmount),
          paidAmount: Value(input.paidAmount),
          deviceId: input.deviceId,
          receivedAt: now,
          createdAt: now,
          updatedAt: now,
        )
      );

      // Map CDC for PO
      await _enqueueCDC('purchase_orders', poId, 'INSERT', {
        'id': poId,
        'po_number': poNumber,
        'supplier_id': input.supplierId,
        'staff_id': input.staffId,
        'status': 'completed',
        'payment_method': input.paymentMethod,
        'total_amount': totalAmount,
        'paid_amount': input.paidAmount,
        'device_id': input.deviceId,
        'received_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      }, input.deviceId);

      // 3. Handle Supplier Payable (if credit/partial payment)
      if (input.paidAmount < totalAmount) {
        final debtAdded = totalAmount - input.paidAmount;
        final supplier = await (_db.select(_db.suppliersTable)..where((s) => s.id.equals(input.supplierId))).getSingle();
        
        await (_db.update(_db.suppliersTable)..where((s) => s.id.equals(input.supplierId))).write(
          SuppliersTableCompanion(
            currentPayable: Value(supplier.currentPayable + debtAdded),
            updatedAt: Value(now),
          )
        );

        // Map CDC for Supplier
        await _enqueueCDC('suppliers', input.supplierId, 'UPDATE', {
          'id': input.supplierId,
          'current_payable': supplier.currentPayable + debtAdded,
          'updated_at': now.toIso8601String(),
        }, input.deviceId);
      }
    });

    return poId;
  }

  Future<void> _enqueueCDC(String table, String recordId, String operation, Map<String, dynamic> payload, String deviceId) async {
    // Generate a unique sequential ID via dart timestamp
    int localSeq = DateTime.now().microsecondsSinceEpoch;
    
    await _db.into(_db.syncQueueTable).insert(
      SyncQueueTableCompanion.insert(
        id: DateTime.now().microsecondsSinceEpoch.toString() + recordId,
        deviceId: deviceId,
        tableName: table,
        recordId: recordId,
        operation: operation,
        payload: payload, // In a real app, jsonEncode this payload string
        localSeq: localSeq,
        createdAt: DateTime.now().toUtc(),
      )
    );
  }
}
