// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group - Unnati Retail OS

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'presentation/core/theme/unnati_theme.dart';
import 'presentation/dashboard/dashboard_screen.dart';
import 'presentation/checkout/checkout_screen.dart';
import 'presentation/compliance/tax_dashboard_screen.dart';
import 'presentation/inventory/inventory_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: UnnatiApp()));
}

class UnnatiApp extends StatelessWidget {
  const UnnatiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unnati Retail OS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: UnnatiTheme.prosperityGreen,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: UnnatiTheme.deepCharcoalDark,
          foregroundColor: Colors.white,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const UnnatiShell(),
    );
  }
}

/// Main navigation shell with a sidebar for Desktop and Bottom Nav for Mobile.
class UnnatiShell extends StatefulWidget {
  const UnnatiShell({super.key});

  @override
  State<UnnatiShell> createState() => _UnnatiShellState();
}

class _UnnatiShellState extends State<UnnatiShell> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    DashboardScreen(),
    CheckoutScreen(),
    InventoryScreen(),
    TaxDashboardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.of(context).size.width > 1200,
              backgroundColor: UnnatiTheme.deepCharcoalDark,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  children: [
                    const Icon(Icons.storefront, color: UnnatiTheme.prosperityGreen, size: 32),
                    const SizedBox(height: 8),
                    Text('Unnati', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
              indicatorColor: UnnatiTheme.prosperityGreen.withOpacity(0.2),
              selectedIconTheme: const IconThemeData(color: UnnatiTheme.prosperityGreen),
              unselectedIconTheme: const IconThemeData(color: Colors.white54),
              selectedLabelTextStyle: GoogleFonts.inter(color: UnnatiTheme.prosperityGreen, fontWeight: FontWeight.w600),
              unselectedLabelTextStyle: GoogleFonts.inter(color: Colors.white54),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')),
                NavigationRailDestination(icon: Icon(Icons.point_of_sale), label: Text('Billing')),
                NavigationRailDestination(icon: Icon(Icons.inventory_2), label: Text('Inventory')),
                NavigationRailDestination(icon: Icon(Icons.gavel), label: Text('Compliance')),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: _screens[_selectedIndex]),
          ],
        ),
      );
    } else {
      return Scaffold(
        body: _screens[_selectedIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Billing'),
            NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Inventory'),
            NavigationDestination(icon: Icon(Icons.gavel), label: 'Compliance'),
          ],
        ),
      );
    }
  }
}
