import 'package:sqflite/sqflite.dart';

import 'package:alex_browser/core/services/database_service.dart';
import 'package:alex_browser/downloads/models/download_item.dart';

/// Persists download metadata (not file bytes — those live on disk, see
/// DownloadManagerService) so the Downloads screen survives app restarts.
class DownloadsRepository {
  DownloadsRepository({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService.instance;

  final DatabaseService _databaseService;

  Future<void> upsert(DownloadItem item) async {
    final Database db = await _databaseService.database;
    await db.insert('downloads', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    final Database db = await _databaseService.database;
    await db.delete('downloads', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<List<DownloadItem>> getAll() async {
    final Database db = await _databaseService.database;
    final List<Map<String, Object?>> rows = await db.query(
      'downloads',
      orderBy: 'created_at DESC',
    );
    return rows.map(DownloadItem.fromMap).toList();
  }

  Future<void> clearCompleted() async {
    final Database db = await _databaseService.database;
    await db.delete('downloads', where: 'status = ?', whereArgs: <Object?>['completed']);
  }

  Future<void> clearAll() async {
    final Database db = await _databaseService.database;
    await db.delete('downloads');
  }
}
