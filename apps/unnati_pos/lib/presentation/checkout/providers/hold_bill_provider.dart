// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/database.dart';
// Note: In a full app, this connects to SaleRepository to store held bills in SQLite.
// For the UI prototype, we'll manage the state in memory.

import 'cart_provider.dart';

class HeldBill {
  final String id;
  final String name;
  final DateTime heldAt;
  final CartState cartState;

  HeldBill({
    required this.id,
    required this.name,
    required this.heldAt,
    required this.cartState,
  });
}

class HoldBillNotifier extends StateNotifier<List<HeldBill>> {
  HoldBillNotifier() : super([]);

  /// Saves the current cart to the pending list and clears the active screen
  void holdCurrentCart(CartState currentCart, String identifierName) {
    if (currentCart.items.isEmpty) return;

    final newBill = HeldBill(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: identifierName.isNotEmpty ? identifierName : 'Customer ${state.length + 1}',
      heldAt: DateTime.now(),
      cartState: currentCart,
    );

    state = [...state, newBill];
  }

  /// Removes a held bill from the list. 
  /// Usually called when a cashier resumes a held bill into the active cart.
  void removeHeldBill(String id) {
    state = state.where((bill) => bill.id != id).toList();
  }
}

final holdBillProvider = StateNotifierProvider<HoldBillNotifier, List<HeldBill>>((ref) {
  return HoldBillNotifier();
});
