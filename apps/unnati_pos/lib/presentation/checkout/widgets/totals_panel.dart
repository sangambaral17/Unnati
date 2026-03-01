// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../providers/cart_provider.dart';
import '../../../../services/vat_service.dart';
import '../../../../data/local/database.dart';

/// Displays the right-side payment panel including:
/// - Customer Search (for Udhari/Credit ledger tracking)
/// - Subtotal, VAT (13%), Grand Total
/// - Checkout Action Buttons
class TotalsPanel extends ConsumerWidget {
  const TotalsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Container(
      color: Colors.blueGrey.shade50,
      child: Column(
        children: [
          _buildCustomerSection(context, ref, cart),
          const Divider(height: 1, thickness: 1),
          Expanded(child: _buildTotalsRows(context, cart)),
          _buildPaymentButtons(context, ref, cart),
        ],
      ),
    );
  }

  Widget _buildCustomerSection(BuildContext context, WidgetRef ref, CartState cart) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Udhari / Customer Search',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          const SizedBox(height: 8),
          if (cart.customerId == null)
            TextField(
              decoration: InputDecoration(
                hintText: 'Search regular customer...',
                prefixIcon: const Icon(Icons.person_search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onSubmitted: (val) {
                // Mock search for user "Ram Kumar"
                if (val.isNotEmpty) {
                  final mockCustomer = CustomersTableData(
                    id: 'cust-123',
                    name: 'Ram Kumar Shrestha',
                    pan: '100123456',
                    currentDebt: 4500, // He owes 4500
                    creditLimit: 50000,
                    isActive: true,
                    updatedAt: DateTime.now(),
                    createdAt: DateTime.now(),
                  );
                  ref.read(cartProvider.notifier).setCustomer(mockCustomer);
                }
              },
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cart.customerName ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (cart.customerPan != null)
                          Text('PAN: ${cart.customerPan}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Current Ledger:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(
                        VatService.formatNPR(cart.currentBalance),
                        style: TextStyle(
                          color: cart.currentBalance > 0 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                    onPressed: () => ref.read(cartProvider.notifier).clearCustomer(),
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalsRows(BuildContext context, CartState cart) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RowDef('Sub Total', VatService.formatNPR(cart.subTotal)),
          const SizedBox(height: 8),
          _RowDef('Taxable Amount', VatService.formatNPR(cart.taxableAmount)),
          const SizedBox(height: 8),
          _RowDef('VAT (13%)', VatService.formatNPR(cart.vatAmount), color: Colors.orange.shade800),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Total', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text(
                VatService.formatNPR(cart.grandTotal),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButtons(BuildContext context, WidgetRef ref, CartState cart) {
    if (cart.items.isEmpty) {
      return Container(height: 120); // Placeholder to maintain standard layout
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cart.customerId != null)
            ElevatedButton.icon(
              onPressed: () {
                // Complete sale as "credit" and create ledger entry
              },
              icon: const Icon(Icons.book),
              label: const Text('PAY LATER (UDHARI)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          if (cart.customerId != null) const SizedBox(height: 8),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                     // Show Fonepay QR dynamically 
                  },
                  icon: const Icon(Icons.qr_code),
                  label: const Text('FONEPAY'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Colors.purple,
                    side: const BorderSide(color: Colors.purple),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Trigger Print Service and complete transaction
                    _completeCashSale(context, ref);
                  },
                  icon: const Icon(Icons.payments),
                  label: const Text('CASH CHECKOUT'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _completeCashSale(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) return;

    // 1. In full app: Call SalesService.completeSale()
    
    // 2. Generate PDF Receipt for Print Preview
    final doc = pw.Document();
    
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, 
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text('UNNATI RETAIL OS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('Tax Invoice', style: const pw.TextStyle(fontSize: 10)),
              pw.Divider(),
              ...cart.items.map((item) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(child: pw.Text('${item.productName} x${item.quantity}')),
                  pw.Text(VatService.formatNPR(item.lineTotal)),
                ],
              )),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SubTotal:'),
                  pw.Text(VatService.formatNPR(cart.subTotal)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('13% VAT:'),
                  pw.Text(VatService.formatNPR(cart.vatAmount)),
                ],
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('GRAND TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(VatService.formatNPR(cart.grandTotal), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text('Thank you for shopping!', style: const pw.TextStyle(fontSize: 10)),
            ]
          );
        },
      ),
    );

    // 3. Trigger Print Preview Dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Receipt_${DateTime.now().millisecondsSinceEpoch}',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale Complete!'), backgroundColor: Colors.green),
      );
    }
    
    // 4. Clear cart for next customer
    ref.read(cartProvider.notifier).clearCart();
  }
}

class _RowDef extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _RowDef(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.blueGrey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: color ?? Colors.blueGrey.shade900,
          ),
        ),
      ],
    );
  }
}
