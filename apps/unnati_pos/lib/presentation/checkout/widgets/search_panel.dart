// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/cart_provider.dart';
import '../../../data/local/database.dart';

/// The live search and barcode scan panel.
/// Optimized for speed: hitting Enter directly adds the top search result.
class SearchPanel extends ConsumerStatefulWidget {
  const SearchPanel({super.key});

  @override
  ConsumerState<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<SearchPanel> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScanOrSearch(String query) {
    if (query.trim().isEmpty) return;
    
    // In actual implementation, we'd query ProductRepository here.
    // For prototype UI, we generate a mock product.
    final mockProduct = ProductsTableData(
      id: 'mock-id',
      sku: 'SKU-${query.toUpperCase()}',
      name: 'Product $query',
      buyingUnitId: 'bx',
      sellingUnitId: 'pc',
      costPrice: 80,
      sellingPrice: 120,
      stockQty: 50,
      isVatApplicable: true,
      reorderLevel: 10,
      isActive: true,
      updatedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );

    final mockUnit = UnitsTableData(
      id: 'pc',
      name: 'Piece',
      shortName: 'pc',
    );

    // Auto-add to cart
    ref.read(cartProvider.notifier).addProduct(mockProduct, mockUnit);
    
    // Clear and refocus for next scan
    _searchController.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              autofocus: true,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Scan Barcode or Search by Name/SKU... (F2)',
                prefixIcon: const Icon(Icons.qr_code_scanner, size: 28),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
              onSubmitted: _onScanOrSearch,
            ),
          ),
        ],
      ),
    );
  }
}
