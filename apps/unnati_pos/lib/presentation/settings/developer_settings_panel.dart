// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/sync_status_provider.dart';
// import '../../data/local/database.dart';

/// Hidden/Admin panel to forcefully trigger sync jobs or clear queues
/// in case of absolute disasters where a payload is eternally 500-erring.
class DeveloperSettingsPanel extends ConsumerWidget {
  const DeveloperSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStatusProvider);
    final notifier = ref.read(syncStatusProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin / Developer Settings'),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Sync Engine & Disaster Recovery',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Connection Status:'),
                      Text(
                        syncState.isOnline ? 'ONLINE' : 'OFFLINE',
                        style: TextStyle(
                            color: syncState.isOnline ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pending Items (CDC Queue):'),
                      Text(
                        '${syncState.pendingItems}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Last Checked:'),
                      Text(
                        syncState.lastCheckedAt?.toIso8601String().substring(11, 19) ?? 'Never',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: syncState.isSyncing
                              ? null
                              : () async {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Triggering Manual Sync...')));
                                  await notifier.triggerManualSync();
                                },
                          icon: syncState.isSyncing
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator())
                              : const Icon(Icons.sync),
                          label: const Text('FORCE MANUAL SYNC'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    '⚠️ DANGER ZONE',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      // Implementation would drop all 'pending' and 'failed' items
                      // from the sync_queue table permanently.
                      // _db.delete(_db.syncQueueTable).go();
                    },
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text('PURGE ENTIRE SYNC QUEUE', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Use only if a corrupted JSON payload is eternally blocking the queue (500 Server Error). Requires Owner PIN.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
