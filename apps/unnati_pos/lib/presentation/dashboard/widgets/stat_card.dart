// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:flutter/material.dart';
import '../../core/theme/unnati_theme.dart';

/// A reusable 'Glance Card' for the Dashboard Top Row.
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final String? subtitle;
  final bool isAlert;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.subtitle,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isAlert ? 4 : 1,
      surfaceTintColor: isAlert ? Colors.red.shade50 : Colors.white,
      shadowColor: isAlert ? Colors.red.shade100 : Colors.black12,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isAlert ? UnnatiTheme.alertRed : UnnatiTheme.deepCharcoalLight,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (iconColor ?? UnnatiTheme.prosperityGreen).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: iconColor ?? UnnatiTheme.prosperityGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isAlert ? UnnatiTheme.alertRed : UnnatiTheme.deepCharcoal,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
