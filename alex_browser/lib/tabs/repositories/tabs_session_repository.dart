import 'package:sqflite/sqflite.dart';

import 'package:alex_browser/core/services/database_service.dart';
import 'package:alex_browser/tabs/models/browser_tab.dart';

/// Persists the *normal* (non-private) tab session so tabs can be restored
/// after the app is closed and reopened, when the user has enabled
/// "Restore tabs on start" in Settings. Private tabs are intentionally
/// never written here — see TabsController.persistSession.
class TabsSessionRepository {
  TabsSessionRepository({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService.instance;

  final DatabaseService _databaseService;

  /// Overwrites the entire saved session with the given ordered list of
  /// normal tabs. [activeTabId] marks which tab should be focused on
  /// restore.
  Future<void> saveSession(List<BrowserTab> normalTabs, {String? activeTabId}) async {
    final Database db = await _databaseService.database;
    await db.transaction((Transaction txn) async {
      await txn.delete('tabs_session');
      for (int i = 0; i < normalTabs.length; i++) {
        final BrowserTab tab = normalTabs[i];
        if (tab.isPrivate) continue;
        if (tab.url.isEmpty) continue;
        await txn.insert(
          'tabs_session',
          tab.toMap(sortOrder: i, isActive: tab.id == activeTabId),
        );
      }
    });
  }

  Future<List<BrowserTab>> restoreSession() async {
    final Database db = await _databaseService.database;
    final List<Map<String, Object?>> rows = await db.query(
      'tabs_session',
      orderBy: 'sort_order ASC',
    );
    return rows.map(BrowserTab.fromMap).toList();
  }

  Future<String?> restoreActiveTabId() async {
    final Database db = await _databaseService.database;
    final List<Map<String, Object?>> rows = await db.query(
      'tabs_session',
      where: 'is_active = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as String?;
  }

  Future<void> clear() async {
    final Database db = await _databaseService.database;
    await db.delete('tabs_session');
  }
}
