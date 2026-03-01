// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/database.dart';
import '../../../services/sales_service.dart';
import '../../../core/auth/auth_provider.dart';

// Provide the SalesService (assuming databaseProvider exists in DI setup)
// We will define databaseProvider here for simplicity, but usually it's in a core/di file.
// final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());
// final salesServiceProvider = Provider<SalesService>((ref) {
//   return SalesService(ref.watch(databaseProvider));
// });

/// Holds the current state of the active checkout cart.
class CartState {
  final List<SaleLineInput> items;
  final String? customerId;
  final String? customerName;
  final String? customerPan;
  final double currentBalance; // Udhari balance if customer selected
  final String paymentMethod; 

  // Computed totals for UI display
  final double subTotal;
  final double taxableAmount;
  final double vatAmount;
  final double grandTotal;

  const CartState({
    this.items = const [],
    this.customerId,
    this.customerName,
    this.customerPan,
    this.currentBalance = 0,
    this.paymentMethod = 'cash',
    this.subTotal = 0,
    this.taxableAmount = 0,
    this.vatAmount = 0,
    this.grandTotal = 0,
  });

  CartState copyWith({
    List<SaleLineInput>? items,
    String? customerId,
    String? customerName,
    String? customerPan,
    double? currentBalance,
    String? paymentMethod,
    double? subTotal,
    double? taxableAmount,
    double? vatAmount,
    double? grandTotal,
    bool clearCustomer = false,
  }) {
    return CartState(
      items: items ?? this.items,
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      customerName: clearCustomer ? null : (customerName ?? this.customerName),
      customerPan: clearCustomer ? null : (customerPan ?? this.customerPan),
      currentBalance: clearCustomer ? 0 : (currentBalance ?? this.currentBalance),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      subTotal: subTotal ?? this.subTotal,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      vatAmount: vatAmount ?? this.vatAmount,
      grandTotal: grandTotal ?? this.grandTotal,
    );
  }
}

/// Riverpod StateNotifier to manage the active cart.
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  /// Adds a product to the cart. If it already exists, increments qty.
  void addProduct(ProductsTableData product, UnitsTableData primaryUnit) {
    final existingIndex = state.items.indexWhere((i) => i.productId == product.id && i.unitId == primaryUnit.id);
    
    List<SaleLineInput> newItems = List.from(state.items);

    if (existingIndex >= 0) {
      final existing = newItems[existingIndex];
      newItems[existingIndex] = SaleLineInput(
        productId: existing.productId,
        productName: existing.productName,
        unitId: existing.unitId,
        quantity: existing.quantity + 1,
        unitPrice: existing.unitPrice,
        costPrice: existing.costPrice,
        discountPct: existing.discountPct,
        isVatApplicable: existing.isVatApplicable,
      );
    } else {
      newItems.add(SaleLineInput(
        productId: product.id,
        productName: product.name,
        unitId: primaryUnit.id,
        quantity: 1,
        unitPrice: product.sellingPrice,
        costPrice: product.costPrice,
        discountPct: 0,
        isVatApplicable: product.isVatApplicable,
      ));
    }

    _updateStateAndTotals(newItems);
  }

  /// Updates quantity of a specific line item.
  void updateQuantity(int index, double newQty) {
    if (index < 0 || index >= state.items.length) return;
    if (newQty <= 0) {
      removeItem(index);
      return;
    }

    List<SaleLineInput> newItems = List.from(state.items);
    final existing = newItems[index];

    newItems[index] = SaleLineInput(
      productId: existing.productId,
      productName: existing.productName,
      unitId: existing.unitId,
      quantity: newQty,
      unitPrice: existing.unitPrice,
      costPrice: existing.costPrice,
      discountPct: existing.discountPct,
      isVatApplicable: existing.isVatApplicable,
    );

    _updateStateAndTotals(newItems);
  }

  /// Changes the unit of a specific line item (e.g., Box -> Piece).
  /// Required factor logic should be done before calling this to adjust unitPrice.
  void switchUnit(int index, String newUnitId, double newUnitPrice) {
    if (index < 0 || index >= state.items.length) return;
    
    List<SaleLineInput> newItems = List.from(state.items);
    final existing = newItems[index];

    newItems[index] = SaleLineInput(
      productId: existing.productId,
      productName: existing.productName,
      unitId: newUnitId,
      quantity: existing.quantity, // Keep same qty, but unit changed
      unitPrice: newUnitPrice,     // Updated price based on conversion factor
      costPrice: existing.costPrice, // Simplification: might need factor adjustment too depending on business rule
      discountPct: existing.discountPct,
      isVatApplicable: existing.isVatApplicable,
    );

    _updateStateAndTotals(newItems);
  }

  void removeItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    List<SaleLineInput> newItems = List.from(state.items)..removeAt(index);
    _updateStateAndTotals(newItems);
  }

  void setCustomer(CustomersTableData customer) {
    state = state.copyWith(
      customerId: customer.id,
      customerName: customer.name,
      customerPan: customer.pan,
      currentBalance: customer.currentDebt,
    );
  }

  void clearCustomer() {
    state = state.copyWith(clearCustomer: true);
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void clearCart() {
    state = const CartState();
  }

  /// Recalculates live totals for the UI (Matches SalesService Logic)
  void _updateStateAndTotals(List<SaleLineInput> newItems) {
    double taxableAmount = 0;
    double nonTaxableAmount = 0;

    for (final item in newItems) {
      if (item.isVatApplicable) {
        taxableAmount += item.lineTotal;
      } else {
        nonTaxableAmount += item.lineTotal;
      }
    }

    final subTotal = taxableAmount + nonTaxableAmount;
    final vatAmount = _round2(taxableAmount * 0.13); // 13% Nepal VAT
    final grandTotal = _round2(subTotal + vatAmount);

    state = state.copyWith(
      items: newItems,
      subTotal: subTotal,
      taxableAmount: taxableAmount,
      vatAmount: vatAmount,
      grandTotal: grandTotal,
    );
  }

  double _round2(double v) => (v * 100).round() / 100;
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});
