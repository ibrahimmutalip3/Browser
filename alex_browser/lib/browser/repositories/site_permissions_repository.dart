import 'package:sqflite/sqflite.dart';

import 'package:alex_browser/core/services/database_service.dart';
import 'package:alex_browser/core/services/permission_service.dart';

/// A single remembered per-origin decision, e.g. "https://meet.example.com
/// is allowed to use the Camera".
class SitePermissionEntry {
  const SitePermissionEntry({
    required this.origin,
    required this.type,
    required this.granted,
    required this.updatedAt,
  });

  final String origin;
  final WebPermissionType type;
  final bool granted;
  final DateTime updatedAt;

  factory SitePermissionEntry.fromMap(Map<String, Object?> map) {
    return SitePermissionEntry(
      origin: map['origin']! as String,
      type: WebPermissionType.values.firstWhere(
        (WebPermissionType t) => t.name == map['permission_type'],
      ),
      granted: (map['granted'] as int) == 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']! as int),
    );
  }
}

/// Persists the user's per-site permission decisions (camera, microphone,
/// location, notifications) so a site that was already granted or denied
/// access doesn't re-prompt on every visit — mirrors the "Site settings"
/// behavior of Chrome/Safari. Backed by the shared SQLite database.
class SitePermissionsRepository {
  SitePermissionsRepository({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService.instance;

  final DatabaseService _databaseService;

  Future<void> remember({
    required String origin,
    required WebPermissionType type,
    required bool granted,
  }) async {
    final Database db = await _databaseService.database;
    await db.insert(
      'site_permissions',
      <String, Object?>{
        'origin': origin,
        'permission_type': type.name,
        'granted': granted ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns the remembered decision for [origin]/[type], or null if the
  /// user has never been asked (or the decision was cleared).
  Future<bool?> lookup({required String origin, required WebPermissionType type}) async {
    final Database db = await _databaseService.database;
    final List<Map<String, Object?>> rows = await db.query(
      'site_permissions',
      where: 'origin = ? AND permission_type = ?',
      whereArgs: <Object?>[origin, type.name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['granted'] as int) == 1;
  }

  Future<List<SitePermissionEntry>> getForOrigin(String origin) async {
    final Database db = await _databaseService.database;
    final List<Map<String, Object?>> rows = await db.query(
      'site_permissions',
      where: 'origin = ?',
      whereArgs: <Object?>[origin],
    );
    return rows.map(SitePermissionEntry.fromMap).toList();
  }

  Future<List<SitePermissionEntry>> getAll() async {
    final Database db = await _databaseService.database;
    final List<Map<String, Object?>> rows = await db.query(
      'site_permissions',
      orderBy: 'updated_at DESC',
    );
    return rows.map(SitePermissionEntry.fromMap).toList();
  }

  Future<void> clearForOrigin(String origin) async {
    final Database db = await _databaseService.database;
    await db.delete('site_permissions', where: 'origin = ?', whereArgs: <Object?>[origin]);
  }

  Future<void> clearAll() async {
    final Database db = await _databaseService.database;
    await db.delete('site_permissions');
  }
}
