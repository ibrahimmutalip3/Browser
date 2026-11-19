import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:alex_browser/bookmarks/models/bookmark.dart';
import 'package:alex_browser/core/services/database_service.dart';

/// Persists bookmarks and bookmark folders. Backed by the shared SQLite
/// database (see DatabaseService).
class BookmarksRepository {
  BookmarksRepository({DatabaseService? databaseService, Uuid? uuid})
      : _databaseService = databaseService ?? DatabaseService.instance,
        _uuid = uuid ?? const Uuid();

  final DatabaseService _databaseService;
  final Uuid _uuid;

  Future<Bookmark> add({required String url, required String title, String? faviconUrl, String? folderId}) async {
    final Database db = await _databaseService.database;
    final Bookmark bookmark = Bookmark(
      id: _uuid.v4(),
      url: url,
      title: title.isEmpty ? url : title,
      faviconUrl: faviconUrl,
      folderId: folderId,
      createdAt: DateTime.now(),
    );
    await db.insert('bookmarks', bookmark.toMap());
    return bookmark;
  }

  Future<void> remove(String id) async {
    final Database db = await _databaseService.database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> rename(String id, String newTitle) async {
    final Database db = await _databaseService.database;
    await db.update('bookmarks', <String, Object?>{'title': newTitle}, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> move(String id, {String? folderId}) async {
    final Database db = await _databaseService.database;
    await db.update('bookmarks', <String, Object?>{'folder_id': folderId}, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<bool> isBookmarked(String url) async {
    final Database db = await _databaseService.database;
    final List<Map<String, Object?>> rows = await db.query('bookmarks', where: 'url = ?', whereArgs: <Object?>[url], limit: 1);
    return rows.isNotEmpty;
  }

  Future<Bookmark?> findByUrl(String url) async {
    final Database db = await _databaseService.database;
    final List<Map<String, Object?>> rows = await db.query('bookmarks', where: 'url = ?', whereArgs: <Object?>[url], limit: 1);
    if (rows.isEmpty) return null;
    return Bookmark.fromMap(rows.first);
  }

  Future<List<Bookmark>> getAll({String? folderId}) async {
    final Database db = await _databaseService.database;
    final List<Map<String, Object?>> rows = await db.query(
      'bookmarks',
      where: folderId == null ? 'folder_id IS NULL' : 'folder_id = ?',
      whereArgs: folderId == null ? null : <Object?>[folderId],
      orderBy: 'sort_order ASC, created_at DESC',
    );
    return rows.map(Bookmark.fromMap).toList();
  }

  Future<List<Bookmark>> getAllFlat() async {
    final Database db = await _databaseService.database;
    final List<Map<String, Object?>> rows = await db.query('bookmarks', orderBy: 'created_at DESC');
    return rows.map(Bookmark.fromMap).toList();
  }

  Future<List<Bookmark>> search(String query) async {
    if (query.trim().isEmpty) return getAllFlat();
    final Database db = await _databaseService.database;
    final String like = '%${query.trim()}%';
    final List<Map<String, Object?>> rows = await db.query(
      'bookmarks',
      where: 'title LIKE ? OR url LIKE ?',
      whereArgs: <Object?>[like, like],
      orderBy: 'created_at DESC',
    );
    return rows.map(Bookmark.fromMap).toList();
  }

  Future<BookmarkFolder> addFolder(String name, {String? parentId}) async {
    final Database db = await _databaseService.database;
    final BookmarkFolder folder = BookmarkFolder(
      id: _uuid.v4(),
      name: name,
      parentId: parentId,
      createdAt: DateTime.now(),
    );
    await db.insert('bookmark_folders', folder.toMap());
    return folder;
  }

  Future<void> removeFolder(String id) async {
    final Database db = await _databaseService.database;
    await db.delete('bookmark_folders', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<void> renameFolder(String id, String newName) async {
    final Database db = await _databaseService.database;
    await db.update('bookmark_folders', <String, Object?>{'name': newName}, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<List<BookmarkFolder>> getFolders({String? parentId}) async {
    final Database db = await _databaseService.database;
    final List<Map<String, Object?>> rows = await db.query(
      'bookmark_folders',
      where: parentId == null ? 'parent_id IS NULL' : 'parent_id = ?',
      whereArgs: parentId == null ? null : <Object?>[parentId],
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(BookmarkFolder.fromMap).toList();
  }
}
