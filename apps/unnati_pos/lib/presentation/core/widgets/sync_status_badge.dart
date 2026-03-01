// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sync_status_provider.dart';
import '../../settings/developer_settings_panel.dart'; // We'll build this next

/// A small UI badge to be placed in the AppBar.
/// Shows a green dot if Online, red if Offline, and indicates pending queue size.
class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStatusProvider);

    return InkWell(
      onTap: () {
        // Open Developer Settings / Admin panel to view sync details
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DeveloperSettingsPanel()));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status Dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: syncState.isOnline ? Colors.greenAccent : Colors.redAccent,
                boxShadow: [
                  BoxShadow(
                    color: (syncState.isOnline ? Colors.green : Colors.red).withOpacity(0.5),
                    blurRadius: 4,
                  )
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Text Indicator
            Text(
              syncState.isOnline ? 'Online' : 'Working Offline',
              style: TextStyle(
                color: syncState.isOnline ? Colors.white : Colors.red[200],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            if (syncState.pendingItems > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  '(${syncState.pendingItems} pending)',
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                ),
              ),
            if (syncState.isSyncing)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
