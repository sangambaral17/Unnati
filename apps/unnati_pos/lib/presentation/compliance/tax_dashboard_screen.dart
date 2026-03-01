// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../../core/theme/unnati_theme.dart';
import 'services/tax_report_service.dart';
import '../../data/local/database.dart';

// Provides the DB instance
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

class TaxDashboardScreen extends ConsumerStatefulWidget {
  const TaxDashboardScreen({super.key});

  @override
  ConsumerState<TaxDashboardScreen> createState() => _TaxDashboardScreenState();
}

class _TaxDashboardScreenState extends ConsumerState<TaxDashboardScreen> {
  int _selectedYear = NepaliDateTime.now().year;
  int _selectedMonth = NepaliDateTime.now().month;

  void _triggerAnnexure13() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compiling Annexure 13 Sales Book (Bikri Khata)...')));
    final db = ref.read(databaseProvider);
    final reportService = TaxReportService(db);
    await reportService.generateAnnexure13(_selectedYear, _selectedMonth);
  }

  void _triggerAnnexure12() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Annexure 12 Purchase Book (Kharid Khata) coming soon.'), backgroundColor: UnnatiTheme.warningOrange));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IRD Compliance & Audit Engine'),
        backgroundColor: UnnatiTheme.deepCharcoalDark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Month/Year Selection (Bikram Sambat)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    decoration: const InputDecoration(labelText: 'Fiscal Year (B.S.)'),
                    items: [2080, 2081, 2082].map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                    onChanged: (val) => setState(() => _selectedYear = val!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(labelText: 'Month'),
                    items: List.generate(12, (index) => index + 1).map((m) => DropdownMenuItem(value: m, child: Text(NepaliDateFormat.MMMM().format(NepaliDateTime(2080, m))))).toList(),
                    onChanged: (val) => setState(() => _selectedMonth = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Statutory Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildReportCard(
                    title: 'Annexure 13 (Sales Book)',
                    subtitle: 'Bikri Khata for IRD. Tracks all Daily Output VAT.',
                    icon: Icons.receipt_long,
                    color: UnnatiTheme.prosperityGreen,
                    onTap: _triggerAnnexure13,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildReportCard(
                    title: 'Annexure 12 (Purchase Book)',
                    subtitle: 'Kharid Khata for IRD. Tracks Input VAT (from POs).',
                    icon: Icons.inventory,
                    color: UnnatiTheme.infoBlue,
                    onTap: _triggerAnnexure12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Security & Audit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.security, color: UnnatiTheme.deepCharcoal, size: 32),
              title: const Text('View Immutable Audit Trail'),
              subtitle: const Text('Track every price change, cancelled invoice, and hardware login.'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fetching local AuditTrail logs...')));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                   Text('Export PDF', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                   const SizedBox(width: 8),
                   Icon(Icons.picture_as_pdf, color: color, size: 18),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
