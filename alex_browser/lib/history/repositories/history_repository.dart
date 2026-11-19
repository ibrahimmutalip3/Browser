import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:alex_browser/core/constants/app_constants.dart';
import 'package:alex_browser/core/services/database_service.dart';
import 'package:alex_browser/history/models/history_entry.dart';

/// Persists and queries browsing history. Backed by the shared SQLite
/// database (see DatabaseService). Never invoked for private/incognito
/// tabs — callers are responsible for that check (TabsController only
/// calls [recordVisit] for non-private tabs).
class HistoryRepository {
  HistoryRepository({DatabaseService? databaseService, Uuid? uuid})
      : _databaseService = databaseService ?? DatabaseService.instance,
        _uuid = uuid ?? const Uuid();

  final DatabaseService _databaseService;
  final Uuid _uuid;

  Future<void> recordVisit({required String url, required String title, String? faviconUrl}) async {
    if (url.isEmpty || url == 'about:blank' || url == AppConstants.newTabUrl) return;

    final Database db = await _databaseService.database;
    final HistoryEntry entry = HistoryEntry(
      id: _uuid.v4(),
      url: url,
      title: title.isEmpty ? url : title,
      faviconUrl: faviconUrl,
      visitedAt: DateTime.now(),
    );
    await db.insert('history', entry.toMap());
    await _prune(db);
  }

  Future<void> _prune(Database db) async {
    final List<Map<String, Object?>> countRows = await db.rawQuery('SELECT COUNT(*) AS c FROM history');
    final int count = Sqflite.firstIntValue(countRows) ?? 0;
    if (count <= AppConstants.maxHistoryEntries) return;

    final int excess = count - AppConstants.maxHistoryEntries;
    await db.rawDelete(
      'DELETE FROM history WHERE id IN '
      '(SELECT id FROM history ORDER BY visited_at ASC LIMIT ?)',
      <Object?>[excess],
    );
  }

  Future<List<HistoryEntry>> getAll({int limit = 500, int offset = 0}) async {
    final Database db = await _databaseService.database;
    final List<Map<String, Object?>> rows = await db.query(
      'history',
      orderBy: 'visited_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(HistoryEntry.fromMap).toList();
  }

  Future<List<HistoryEntry>> search(String query) async {
    if (query.trim().isEmpty) return getAll();
    final Database db = await _databaseService.database;
    final String like = '%${query.trim()}%';
    final List<Map<String, Object?>> rows = await db.query(
      'history',
      where: 'title LIKE ? OR url LIKE ?',
      whereArgs: <Object?>[like, like],
      orderBy: 'visited_at DESC',
      limit: 500,
    );
    return rows.map(HistoryEntry.fromMap).toList();
  }

  Future<void> deleteEntry(String id) async {
    final Database db = await _databaseService.database;
    await db.delete('history', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> clearAll() async {
    final Database db = await _databaseService.database;
    await db.delete('history');
  }

  /// Clears history entries newer than [since] — powers the "Clear
  /// Browsing Data" time-range picker (last hour / 24h / 7 days / all
  /// time).
  Future<void> clearSince(DateTime since) async {
    final Database db = await _databaseService.database;
    await db.delete(
      'history',
      where: 'visited_at >= ?',
      whereArgs: <Object?>[since.millisecondsSinceEpoch],
    );
  }
}
