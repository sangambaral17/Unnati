// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

class LocalBackupService {
  /// Exports exactly the Drift SQLite database to a local file system (e.g. USB Drive)
  /// ensuring physical data sovereignty for the shop owner per IRD regulations.
  static Future<String?> exportDatabaseBackup(BuildContext context) async {
    try {
      // 1. Locate current active SQLite file
      final appDir = await getApplicationDocumentsDirectory();
      final dbFolder = p.join(appDir.path, 'UnnatiDb');
      final dbFile = File(p.join(dbFolder, 'unnati_local.sqlite'));

      if (!dbFile.existsSync()) {
        throw Exception('Primary database file missing.');
      }

      // 2. Determine target save location (In a real app, use file_saver or path_provider to ask user)
      // For this Windows demo, we'll save it gracefully to the Documents folder with a timestamp.
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFileName = 'Unnati_Hardware_Backup_$timestamp.unnati';
      final backupDir = await getApplicationDocumentsDirectory();
      final targetPath = p.join(backupDir.path, backupFileName);

      // 3. Copy the bits directly (Atomic OS operation)
      await dbFile.copy(targetPath);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Backup Saved Local to: $targetPath'), backgroundColor: Colors.green),
        );
      }

      return targetPath;
    } catch (e) {
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Local Backup Failed: $e'), backgroundColor: Colors.red),
         );
      }
      return null;
    }
  }
}
