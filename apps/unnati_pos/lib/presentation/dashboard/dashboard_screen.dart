// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';

import 'providers/dashboard_metrics_provider.dart';
import 'widgets/stat_card.dart';
import '../../../services/vat_service.dart';
import '../../core/theme/unnati_theme.dart';
import '../../core/widgets/sync_status_badge.dart';

/// Owner's Command Center (Dashboard)
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Unnati Command Center'),
            const SizedBox(width: 16),
            const SyncStatusBadge(), // Integrated Sync Guardian UI
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Metrics',
            onPressed: () => ref.read(dashboardMetricsProvider.notifier).refresh(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildUniversalSearch(context),
            Expanded(
              child: metricsAsync.when(
                data: (metrics) => _buildDashboardContent(context, metrics),
                loading: () => _buildShimmerLoading(context),
                error: (err, stack) => Center(child: Text('Error loading dashboard: $err')),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
            // Navigate to High Velocity Checkout Screen
        },
        backgroundColor: UnnatiTheme.prosperityGreen,
        icon: const Icon(Icons.point_of_sale, color: Colors.white),
        label: const Text('NEW SALE (F1)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildUniversalSearch(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.white,
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search products, customers (Udhari), or invoice numbers...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (query) {
          // Trigger universal search across Drift tables
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Searching for: $query')));
        },
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, DashboardMetrics metrics) {
    // Responsive grid counts
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 1200 ? 4 : (screenWidth > 800 ? 2 : 1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 1. TOP ROW: Glance Cards ─────────────────────────────────────
          GridView.count(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: crossAxisCount == 1 ? 2.5 : 1.5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              StatCard(
                title: "TODAY's SALES (NPR)",
                value: VatService.formatNPR(metrics.todaySalesTotal),
                icon: Icons.trending_up,
                iconColor: UnnatiTheme.prosperityGreen,
                subtitle: '+12% vs yesterday', // Static mock for now
              ),
              StatCard(
                title: 'ACTIVE UDHARI (CREDIT)',
                value: VatService.formatNPR(metrics.activeUdhariTotal),
                icon: Icons.book,
                iconColor: UnnatiTheme.warningOrange,
                subtitle: 'Outstanding balance across all customers',
              ),
              StatCard(
                title: 'LOW STOCK ALERT',
                value: '${metrics.lowStockCount} Items',
                icon: Icons.warning_amber_rounded,
                iconColor: UnnatiTheme.alertRed,
                isAlert: metrics.lowStockCount > 0,
                subtitle: 'Items below reorder level. Click to restock.',
              ),
              StatCard(
                title: 'PENDING SYNC',
                value: '${metrics.pendingSyncCount} Rows',
                icon: Icons.cloud_upload_outlined,
                iconColor: metrics.pendingSyncCount > 50 ? UnnatiTheme.warningOrange : UnnatiTheme.infoBlue,
                subtitle: 'Pending local changes queued for server',
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ─── 2. MIDDLE ROW: 7-Day Chart ────────────────────────────────
          const Text(
            'Sales Trend (Last 7 Days)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.only(right: 24, left: 16, top: 32, bottom: 16),
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            final daysAgo = 6 - value.toInt();
                            if (daysAgo == 0) return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Today'));
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text('-$daysAgo d', style: const TextStyle(fontSize: 12)),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: metrics.weeklySalesTrend.asMap().entries.map((e) {
                          return FlSpot(e.key.toDouble(), e.value);
                        }).toList(),
                        isCurved: true,
                        color: UnnatiTheme.prosperityGreen,
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: UnnatiTheme.prosperityGreenLight.withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 1200 ? 4 : (screenWidth > 800 ? 2 : 1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: crossAxisCount == 1 ? 2.5 : 1.5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(4, (index) => Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.white,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            )),
          ),
          const SizedBox(height: 32),
          Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.white,
            child: Container(
              height: 24,
              width: 200,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.white,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
