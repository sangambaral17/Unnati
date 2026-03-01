// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/search_panel.dart';
import 'widgets/cart_panel.dart';
import 'widgets/totals_panel.dart';
import 'providers/hold_bill_provider.dart';
import 'providers/cart_provider.dart';

/// The High-Velocity Checkout Screen.
/// Optimized for physical keyboards (Windows Desktop) and touch (Android Mobile/Tablet).
class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Basic responsiveness check
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.f1): const Intent.doNothing(), // Handled via raw listener below or custom intents
        LogicalKeySet(LogicalKeyboardKey.f5): const Intent.doNothing(),
        LogicalKeySet(LogicalKeyboardKey.f10): const Intent.doNothing(),
        LogicalKeySet(LogicalKeyboardKey.escape): const Intent.doNothing(),
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.f1) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('F1: New Sale Started'), backgroundColor: Colors.green));
              ref.read(cartProvider.notifier).clearCart();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.f5) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('F5: Printing Last Receipt...'), backgroundColor: Colors.green));
              // In production, trigger PrintingService
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.f10) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('F10: Switched to Udhari (Credit) Mode'), backgroundColor: Colors.blue));
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ESC: Cart Cleared'), backgroundColor: Colors.red));
              ref.read(cartProvider.notifier).clearCart();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('New Sale (Billing) - Press F1 for Help'),
            backgroundColor: Colors.blueGrey[900],
            foregroundColor: Colors.white,
            actions: [
              _buildHoldBillBadge(context, ref),
              const SizedBox(width: 16),
            ],
          ),
          body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Search & Cart (Flexible width)
        Expanded(
          flex: 6,
          child: Column(
            children: [
              SearchPanel(),
              Expanded(child: CartPanel()),
            ],
          ),
        ),
        // Vertical Divider
        VerticalDivider(width: 1, thickness: 1),
        // Right Column: Totals & Udhari Flow (Fixed width for desktop standard)
        SizedBox(
          width: 400,
          child: TotalsPanel(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.blueGrey,
            tabs: [
              Tab(icon: Icon(Icons.shopping_cart), text: 'Cart'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Payment'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: Build the cart
                const Column(
                  children: [
                    SearchPanel(),
                    Expanded(child: CartPanel()),
                  ],
                ),
                // Tab 2: Take payment
                const TotalsPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoldBillBadge(BuildContext context, WidgetRef ref) {
    final heldBills = ref.watch(holdBillProvider);
    final cart = ref.watch(cartProvider);

    return Row(
      children: [
        if (cart.items.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () {
              // Show dialog to name the held bill
              _showHoldBillDialog(context, ref, cart);
            },
            icon: const Icon(Icons.pause, color: Colors.orange),
            label: const Text('Hold Bill', style: TextStyle(color: Colors.orange)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.orange),
            ),
          ),
        const SizedBox(width: 16),
        Stack(
          alignment: Alignment.topRight,
          children: [
            IconButton(
              icon: const Icon(Icons.list_alt),
              tooltip: 'Held Bills',
              onPressed: () {
                // Show held bills drawer/dropdown
              },
            ),
            if (heldBills.isNotEmpty)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${heldBills.length}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _showHoldBillDialog(BuildContext context, WidgetRef ref, CartState cart) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hold Current Bill'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Customer Name / Identifier (Optional)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (val) {
            ref.read(holdBillProvider.notifier).holdCurrentCart(cart, val);
            ref.read(cartProvider.notifier).clearCart();
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(holdBillProvider.notifier).holdCurrentCart(cart, nameController.text);
              ref.read(cartProvider.notifier).clearCart(); // Clear active screen
              Navigator.pop(context);
            },
            child: const Text('Hold'),
          ),
        ],
      ),
    );
  }
}
