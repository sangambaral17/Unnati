// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../../data/local/database.dart';
import '../../core/providers/sync_status_provider.dart'; // We can reuse pending logic

// Expose the database globally (typically via a DI tool, simplified here)
// final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

class DashboardMetrics {
  final double todaySalesTotal;
  final double activeUdhariTotal;
  final int lowStockCount;
  final int pendingSyncCount;
  final List<double> weeklySalesTrend; // 7 floats for the line chart

  const DashboardMetrics({
    this.todaySalesTotal = 0.0,
    this.activeUdhariTotal = 0.0,
    this.lowStockCount = 0,
    this.pendingSyncCount = 0,
    this.weeklySalesTrend = const [0, 0, 0, 0, 0, 0, 0],
  });
}

class DashboardMetricsNotifier extends StateNotifier<AsyncValue<DashboardMetrics>> {
  final AppDatabase _db;
  final SyncStatusNotifier _syncNotifier;

  DashboardMetricsNotifier(this._db, this._syncNotifier) : super(const AsyncLoading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      
      // 1. Today's Sales
      // Sum grand_total where sold_at >= startOfDay and status == 'completed'
      final salesQuery = _db.select(_db.salesTable)
        ..where((s) => s.soldAt.isBiggerOrEqualValue(startOfDay) & s.status.equals('completed'));
      final todaySales = await salesQuery.get();
      final todayTotal = todaySales.fold<double>(0, (sum, sale) => sum + sale.grandTotal);

      // 2. Total Active Udhari
      // Sum current_debt from all customers where current_debt > 0
      final udhariQuery = _db.select(_db.customersTable)..where((c) => c.currentDebt.isBiggerThanValue(0));
      final udhariCustomers = await udhariQuery.get();
      final totalUdhari = udhariCustomers.fold<double>(0, (sum, cust) => sum + cust.currentDebt);

      // 3. Low Stock 
      // Count products where stock_qty <= reorder_level
      final lowStockQuery = _db.select(_db.productsTable)..where((p) => p.stockQty.isSmallerOrEqual(p.reorderLevel));
      final lowStockItems = await lowStockQuery.get();
      final lowStockCount = lowStockItems.length;

      // 4. Pending Sync (Reuse logic)
      final syncState = _syncNotifier.state;
      final pendingCount = syncState.pendingItems;

      // 5. Weekly Sales Trend (Last 7 days)
      List<double> trend = List.filled(7, 0.0);
      for (int i = 6; i >= 0; i--) {
        final dayStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        final dayEnd = dayStart.add(const Duration(days: 1));
        
        final dailyQuery = _db.select(_db.salesTable)
          ..where((s) => s.soldAt.isBiggerOrEqualValue(dayStart) & s.soldAt.isSmallerThanValue(dayEnd) & s.status.equals('completed'));
        final dailySales = await dailyQuery.get();
        trend[6 - i] = dailySales.fold<double>(0, (sum, sale) => sum + sale.grandTotal);
      }

      state = AsyncData(DashboardMetrics(
        todaySalesTotal: todayTotal,
        activeUdhariTotal: totalUdhari,
        lowStockCount: lowStockCount,
        pendingSyncCount: pendingCount,
        weeklySalesTrend: trend,
      ));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final dashboardMetricsProvider = StateNotifierProvider<DashboardMetricsNotifier, AsyncValue<DashboardMetrics>>((ref) {
  final db = ref.watch(databaseProvider);
  final syncNotifier = ref.read(syncStatusProvider.notifier);
  return DashboardMetricsNotifier(db, syncNotifier);
});
