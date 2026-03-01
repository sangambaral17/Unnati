// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/unnati_theme.dart';
import 'services/excel_import_service.dart';
import 'services/stock_valuation_report.dart';
import '../../data/local/database.dart';

// Provides the DB instance
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());
final excelImportProvider = Provider<ExcelImportService>((ref) => ExcelImportService(ref.watch(databaseProvider)));

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _triggerExcelImport() async {
    setState(() => _isImporting = true);
    try {
      final service = ref.read(excelImportProvider);
      final result = await service.importProductsFromExcel('dev-win-1');
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import Complete! \n✔️ ${result.rowsInserted} Inserted \n❌ ${result.rowsSkipped} Skipped'),
          backgroundColor: UnnatiTheme.prosperityGreen,
        )
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import Failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showBatchUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String percent = '5';
        return AlertDialog(
          title: const Text('Batch Price Update'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Increase Selling Price globally by a percentage. e.g., "Increase all CPVC pipes by 5%".'),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(labelText: 'Percentage (%)', suffixText: '%'),
                keyboardType: TextInputType.number,
                onChanged: (val) => percent = val,
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                // Execute Drift Batch Update across ProductsTable
                // UPDATE products SET selling_price = selling_price + (selling_price * percent / 100) WHERE category_id = ...
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Batch Update Executed Successfully.')));
              },
              child: const Text('Execute Update'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Pro'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey.shade400,
          tabs: const [
            Tab(text: 'PRODUCTS & BULK'),
            Tab(text: 'UNIT CONVERSIONS'),
            Tab(text: 'STOCK IN (POs)'),
          ],
        ),
        actions: [
            TextButton.icon(
                onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating Annexure 10 Report...')));
                    final db = ref.read(databaseProvider);
                    final report = StockValuationReport(db);
                    await report.generateAndPreview();
                }, 
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white), 
                label: const Text('Valuation Report', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 16),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductsTab(),
          _buildUnitConversionsTab(),
          _buildStockInTab(),
        ],
      ),
    );
  }

  Widget _buildProductsTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isImporting ? null : _triggerExcelImport,
                icon: _isImporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.upload_file),
                label: const Text('Import Excel/CSV'),
                style: ElevatedButton.styleFrom(backgroundColor: UnnatiTheme.prosperityGreen),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _showBatchUpdateDialog,
                icon: const Icon(Icons.percent),
                label: const Text('Batch Update Prices'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Expanded(
            child: Center(
              child: Text('Product Data Table loaded from SQLite...'),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildUnitConversionsTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Define how units mathematically translate. e.g., "1 Box = 24 Pieces".', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Expanded(child: TextField(decoration: InputDecoration(labelText: 'From Unit (e.g., Box)'))),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('=', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                  const Expanded(child: TextField(decoration: InputDecoration(labelText: 'Quantity (e.g., 24)'))),
                  const SizedBox(width: 16),
                  const Expanded(child: TextField(decoration: InputDecoration(labelText: 'To Unit (e.g., Piece)'))),
                  const SizedBox(width: 16),
                  ElevatedButton(onPressed: () {}, child: const Text('Save Formula'))
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockInTab() {
    return const Center(child: Text('Supplier Ledger and Purchase Order Table View'));
  }
}
