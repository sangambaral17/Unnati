// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../../../services/sync_service.dart';
// Note: In real app, databaseProvider is imported from DI
import '../../../data/local/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());
final syncServiceProvider = Provider<SyncService>((ref) => SyncService(ref.watch(databaseProvider)));

class SyncState {
  final bool isOnline;
  final int pendingItems;
  final bool isSyncing;
  final DateTime? lastCheckedAt;

  const SyncState({
    this.isOnline = false,
    this.pendingItems = 0,
    this.isSyncing = false,
    this.lastCheckedAt,
  });

  SyncState copyWith({
    bool? isOnline,
    int? pendingItems,
    bool? isSyncing,
    DateTime? lastCheckedAt,
  }) {
    return SyncState(
      isOnline: isOnline ?? this.isOnline,
      pendingItems: pendingItems ?? this.pendingItems,
      isSyncing: isSyncing ?? this.isSyncing,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }
}

class SyncStatusNotifier extends StateNotifier<SyncState> {
  final SyncService _syncService;
  Timer? _pollingTimer;

  SyncStatusNotifier(this._syncService) : super(const SyncState()) {
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Initial check
    checkStatus();
    // Poll every 10 seconds for real-time UI updates
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => checkStatus());
  }

  /// Checks server reachability and local pending count.
  Future<void> checkStatus() async {
    final pendingCount = await _syncService.getPendingCount();
    final isOnline = await _checkServerHealth();

    if (mounted) {
      state = state.copyWith(
        isOnline: isOnline,
        pendingItems: pendingCount,
        lastCheckedAt: DateTime.now(),
      );
    }
  }

  /// Manually force a sync push, regardless of the WorkManager schedule.
  Future<void> triggerManualSync() async {
    if (state.isSyncing) return;
    
    state = state.copyWith(isSyncing: true);
    
    final success = await _syncService.syncNow();
    
    // Refresh status after sync attempt
    await checkStatus();
    
    if (mounted) {
      state = state.copyWith(isSyncing: false, isOnline: success || state.isOnline);
    }
  }

  Future<bool> _checkServerHealth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString('sync_server_url') ?? 'http://localhost:8080';
      final deviceId = prefs.getString('device_id') ?? 'dev-env';
      
      final res = await http.get(Uri.parse('$baseUrl/api/v1/health/sync/$deviceId'))
          .timeout(const Duration(seconds: 3));
      
      return res.statusCode == 200 || res.statusCode == 404; // 404 means device not found, but server is UP
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }
}

final syncStatusProvider = StateNotifierProvider<SyncStatusNotifier, SyncState>((ref) {
  final sysService = ref.watch(syncServiceProvider);
  return SyncStatusNotifier(sysService);
});
