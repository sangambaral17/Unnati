// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS
// Founder: Sangam Baral

// ignore_for_file: type=lint
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Tables
// ─────────────────────────────────────────────────────────────────────────────

/// Local Product table (mirrors PostgreSQL but lightweight).
class ProductsTable extends Table {
  @override
  String get tableName => 'products';

  TextColumn get id => text()();
  TextColumn get sku => text()();
  TextColumn get barcode => text().nullable()();
  TextColumn get name => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get buyingUnitId => text()();
  TextColumn get sellingUnitId => text()();
  RealColumn get stockQty => real().withDefault(const Constant(0))();

  // Cost price stored locally for Owner; hidden in UI for Cashier role
  RealColumn get costPrice => real().withDefault(const Constant(0))();
  RealColumn get sellingPrice => real().withDefault(const Constant(0))();
  BoolColumn get isVatApplicable => boolean().withDefault(const Constant(false))();
  RealColumn get reorderLevel => real().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Unit table (Roll, Meter, Piece, Kg...)
class UnitsTable extends Table {
  @override
  String get tableName => 'units';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get shortName => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Unit conversion rules per product.
class UnitConversionsTable extends Table {
  @override
  String get tableName => 'unit_conversions';

  TextColumn get id => text()();
  TextColumn get productId => text().references(ProductsTable, #id)();
  TextColumn get fromUnitId => text()();
  TextColumn get toUnitId => text()();
  RealColumn get factor => real()(); // fromUnit * factor = toUnit

  @override
  Set<Column> get primaryKey => {id};
}

/// Product categories (hierarchical: Hardware > Fasteners, Electrical > Wiring).
class ProductCategoriesTable extends Table {
  @override
  String get tableName => 'product_categories';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable()();  // Self-referential for sub-categories
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local Sales table.
class SalesTable extends Table {
  @override
  String get tableName => 'sales';

  TextColumn get id => text()();
  TextColumn get billNumber => text()();
  TextColumn get staffId => text()();
  TextColumn get customerId => text().nullable()();

  /// draft | held | completed | cancelled | refunded
  TextColumn get status => text().withDefault(const Constant('draft'))();

  /// cash | fonepay | credit | transfer
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();

  RealColumn get subTotal => real().withDefault(const Constant(0))();
  RealColumn get discountAmt => real().withDefault(const Constant(0))();
  RealColumn get taxableAmount => real().withDefault(const Constant(0))();
  RealColumn get vatAmount => real().withDefault(const Constant(0))(); // 13%
  RealColumn get grandTotal => real().withDefault(const Constant(0))();
  RealColumn get paidAmount => real().withDefault(const Constant(0))();
  RealColumn get changeAmount => real().withDefault(const Constant(0))();
  RealColumn get netProfit => real().withDefault(const Constant(0))();
  TextColumn get customerPan => text().nullable()();
  TextColumn get fiscalYear => text()(); // e.g., "2081/82"
  TextColumn get fonepayQrRef => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get printCount => integer().withDefault(const Constant(0))();
  TextColumn get deviceId => text()();

  DateTimeColumn get soldAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Line items for each sale.
class SaleItemsTable extends Table {
  @override
  String get tableName => 'sale_items';

  TextColumn get id => text()();
  TextColumn get saleId => text().references(SalesTable, #id)();
  TextColumn get productId => text()();
  TextColumn get productName => text()(); // Denormalized snapshot
  RealColumn get qty => real()();
  TextColumn get unitId => text()();
  RealColumn get unitPrice => real()();
  RealColumn get discountPct => real().withDefault(const Constant(0))();
  BoolColumn get isVatApplicable => boolean().withDefault(const Constant(false))();
  RealColumn get lineTotal => real()();
  RealColumn get costPrice => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Customer (Udhari credit customer).
class CustomersTable extends Table {
  @override
  String get tableName => 'customers';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get pan => text().nullable()();
  TextColumn get address => text().nullable()();
  RealColumn get creditLimit => real().withDefault(const Constant(10000))();
  RealColumn get currentDebt => real().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Immutable ledger entries (Udhari double-entry).
class LedgerEntriesTable extends Table {
  @override
  String get tableName => 'ledger_entries';

  TextColumn get id => text()();
  TextColumn get customerId => text().references(CustomersTable, #id)();
  TextColumn get saleId => text().nullable()();

  /// debit | credit
  TextColumn get type => text()();
  RealColumn get amount => real()();
  RealColumn get runningBalance => real()();
  TextColumn get description => text()();
  TextColumn get staffId => text()();
  TextColumn get paymentMethod => text().nullable()();
  TextColumn get fonepayTxnId => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  BoolColumn get isOverdue => boolean().withDefault(const Constant(false))();
  TextColumn get deviceId => text()();
  DateTimeColumn get entryDate => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// CDC Sync Queue — every local write produces a row here.
class SyncQueueTable extends Table {
  @override
  String get tableName => 'sync_queue';

  TextColumn get id => text()();
  TextColumn get deviceId => text()();
  TextColumn get tableName_ => text().named('table_name')();
  TextColumn get recordId => text()();

  /// INSERT | UPDATE | DELETE
  TextColumn get operation => text()();

  /// Full JSON of the changed entity
  TextColumn get payload => text()();

  IntColumn get localSeq => integer()();

  /// pending | syncing | synced | failed
  TextColumn get status => text().withDefault(const Constant('pending'))();

  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get errorMsg => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// AppDatabase — the single SQLite database instance
// ─────────────────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  ProductsTable,
  UnitsTable,
  UnitConversionsTable,
  ProductCategoriesTable,
  SalesTable,
  SaleItemsTable,
  CustomersTable,
  LedgerEntriesTable,
  SyncQueueTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedDefaultUnits();
        },
      );

  /// Seed default Nepal retail units on first launch.
  Future<void> _seedDefaultUnits() async {
    const units = [
      ('piece-id', 'Piece', 'pc'),
      ('box-id', 'Box', 'bx'),
      ('roll-id', 'Roll', 'Rl'),
      ('meter-id', 'Meter', 'm'),
      ('kg-id', 'Kg', 'kg'),
      ('dozen-id', 'Dozen', 'dz'),
      ('liter-id', 'Liter', 'L'),
      ('bundle-id', 'Bundle', 'bdl'),
      ('feet-id', 'Feet', 'ft'),
    ];
    for (final (id, name, short) in units) {
      await into(unitsTable).insertOnConflictUpdate(
        UnitsTableCompanion.insert(id: id, name: name, shortName: short),
      );
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'Unnati', 'unnati_pos.sqlite'));
    await file.parent.create(recursive: true);
    return NativeDatabase.createInBackground(file);
  });
}
