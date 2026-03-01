// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/cart_provider.dart';
import '../../../../services/vat_service.dart';

/// The central list of scanned items in the current transaction.
class CartPanel extends ConsumerWidget {
  const CartPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    if (cart.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_checkout, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Cart is empty.\nScan a barcode to begin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: cart.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = cart.items[index];

        return Container(
          color: index.isEven ? Colors.transparent : Colors.grey.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // 1. Delete Button
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => notifier.removeItem(index),
              ),
              
              const SizedBox(width: 8),

              // 2. Product Name
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (item.isVatApplicable)
                      const Text('13% VAT Applicable', style: TextStyle(color: Colors.orange, fontSize: 12)),
                  ],
                ),
              ),

              // 3. Multi-Unit Dropdown
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: DropdownButtonFormField<String>(
                    value: item.unitId,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'pc', child: Text('Piece')),
                      DropdownMenuItem(value: 'bx', child: Text('Box (24 pc)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        // In reality, this queries the unit_conversions table.
                        // Mock: if Box, price = original * 24.
                        double newPrice = item.unitPrice;
                        if (val == 'bx' && item.unitId == 'pc') newPrice = item.unitPrice * 24;
                        if (val == 'pc' && item.unitId == 'bx') newPrice = item.unitPrice / 24;
                        notifier.switchUnit(index, val, newPrice);
                      }
                    },
                  ),
                ),
              ),

              // 4. Quantity Controls
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => notifier.updateQuantity(index, item.quantity - 1),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        item.quantity.toStringAsFixed(0),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => notifier.updateQuantity(index, item.quantity + 1),
                    ),
                  ],
                ),
              ),

              // 5. Unit Price
              Expanded(
                flex: 2,
                child: Text(
                  VatService.formatNPR(item.unitPrice),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 16),
                ),
              ),

              // 6. Line Total
              Expanded(
                flex: 2,
                child: Text(
                  VatService.formatNPR(item.lineTotal),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
