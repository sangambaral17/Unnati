// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'dart:convert';
import 'package:drift/drift.dart';
import '../../data/local/database.dart';

class AuditLoggerService {
  final AppDatabase _db;

  AuditLoggerService(this._db);

  /// Logs a highly sensitive action to the IRD Audit Trail and queues it for sync.
  Future<void> logAction({
    required String deviceId,
    required String staffId,
    required String action, // e.g., 'price_change', 'invoice_cancel', 'login'
    String? entityName,
    String? entityId,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
    String? reason,
  }) async {
    final now = DateTime.now().toUtc();
    final logId = 'AUD-${DateTime.now().microsecondsSinceEpoch}';

    final oldJson = oldValue != null ? jsonEncode(oldValue) : null;
    final newJson = newValue != null ? jsonEncode(newValue) : null;

    // 1. Insert into local Audit Trail for IRD compliance reporting
    await _db.into(_db.auditTrailTable).insert(
      AuditTrailTableCompanion.insert(
        id: logId,
        deviceId: deviceId,
        staffId: staffId,
        action: action,
        entityName: Value(entityName),
        entityId: Value(entityId),
        oldValue: Value(oldJson),
        newValue: Value(newJson),
        reason: Value(reason),
        createdAt: now,
      )
    );

    // 2. Map CDC to push log to the central Postgres vault securely
    final localSeq = DateTime.now().microsecondsSinceEpoch;
    await _db.into(_db.syncQueueTable).insert(
      SyncQueueTableCompanion.insert(
        id: 'SYNC-$logId',
        deviceId: deviceId,
        tableName: 'audit_trail',
        recordId: logId,
        operation: 'INSERT',
        payload: {
          'id': logId,
          'device_id': deviceId,
          'staff_id': staffId,
          'action': action,
          'entity_name': entityName,
          'entity_id': entityId,
          'old_value': oldValue, 
          'new_value': newValue,
          'reason': reason,
          'created_at': now.toIso8601String(),
        },
        localSeq: localSeq,
      )
    );
  }
}
