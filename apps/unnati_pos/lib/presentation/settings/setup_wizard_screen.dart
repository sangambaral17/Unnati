// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/unnati_theme.dart';
import '../../data/local/database.dart';
import 'package:drift/drift.dart' as drift;

// Provides the DB instance
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

class SetupWizardScreen extends ConsumerStatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  ConsumerState<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends ConsumerState<SetupWizardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _panController = TextEditingController();
  final _addressController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');

  bool _isSaving = false;

  void _completeSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final db = ref.read(databaseProvider);

    try {
      final now = DateTime.now().toUtc();
      final deviceId = 'DEV-${now.millisecondsSinceEpoch}'; // Mock device ID generator

      // 1. Save Store Profile
      await db.into(db.storeProfileTable).insert(
        StoreProfileTableCompanion.insert(
          id: 'STORE-1',
          name: _nameController.text,
          panVat: _panController.text,
          address: _addressController.text,
          openingBalance: double.parse(_balanceController.text),
          deviceId: deviceId,
          createdAt: now,
        )
      );

      // 2. Queue Initial Handshake CDC (Registers Device to Go Home Server)
      await db.into(db.syncQueueTable).insert(
        SyncQueueTableCompanion.insert(
          id: 'HANDSHAKE-${now.microsecondsSinceEpoch}',
          deviceId: deviceId,
          tableName: 'device_registry',
          recordId: deviceId,
          operation: 'INSERT',
          payload: {
             'device_id': deviceId,
             'device_name': 'Main Register - ${_nameController.text}',
             'store_pan': _panController.text,
             'registered_at': now.toIso8601String(),
          },
          localSeq: now.microsecondsSinceEpoch,
        )
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setup Complete! Ready for First Sale.'), backgroundColor: UnnatiTheme.prosperityGreen)
      );
      
      // In a real flow, use GoRouter to navigate to the Main Dashboard
      // context.go('/');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Setup Failed: $e'), backgroundColor: Colors.red)
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UnnatiTheme.deepCharcoalDark,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(48.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                 BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
              ]
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Welcome to Unnati', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: UnnatiTheme.prosperityGreen)),
                  const SizedBox(height: 8),
                  const Text('Hardware Shop Pro', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 32),
                  
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Shop Name', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _panController,
                    decoration: const InputDecoration(labelText: 'PAN/VAT Number', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Full Address', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _balanceController,
                    decoration: const InputDecoration(labelText: 'Opening Cash Register Balance (Rs.)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 32),
                  
                  ElevatedButton(
                    onPressed: _isSaving ? null : _completeSetup,
                    style: ElevatedButton.styleFrom(
                       padding: const EdgeInsets.symmetric(vertical: 20),
                       backgroundColor: UnnatiTheme.prosperityGreen,
                       foregroundColor: Colors.white,
                    ),
                    child: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Complete Setup & Start Billing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
