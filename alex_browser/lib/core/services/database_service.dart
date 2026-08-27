import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:alex_browser/core/constants/app_constants.dart';

/// Owns the single SQLite [Database] instance used by history, bookmarks,
/// and downloads repositories. Schema creation and migrations live here so
/// there is exactly one source of truth for the on-disk data model.
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _open();
    return _database!;
  }

  Future<Database> _open() async {
    final Directory docsDir = await getApplicationDocumentsDirectory();
    final String dbPath = p.join(docsDir.path, AppConstants.databaseName);

    return openDatabase(
      dbPath,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE history (
        id TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        title TEXT NOT NULL,
        favicon_url TEXT,
        visited_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_history_visited_at ON history(visited_at)');
    await db.execute('CREATE INDEX idx_history_url ON history(url)');

    await db.execute('''
      CREATE TABLE bookmark_folders (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parent_id TEXT,
        created_at INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (parent_id) REFERENCES bookmark_folders(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE bookmarks (
        id TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        title TEXT NOT NULL,
        favicon_url TEXT,
        folder_id TEXT,
        created_at INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (folder_id) REFERENCES bookmark_folders(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_bookmarks_folder ON bookmarks(folder_id)');
    await db.execute('CREATE INDEX idx_bookmarks_url ON bookmarks(url)');

    await db.execute('''
      CREATE TABLE downloads (
        id TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        mime_type TEXT,
        total_bytes INTEGER,
        received_bytes INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        completed_at INTEGER
      )
    ''');
    await db.execute('CREATE INDEX idx_downloads_created_at ON downloads(created_at)');

    await db.execute('''
      CREATE TABLE tabs_session (
        id TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        title TEXT NOT NULL,
        favicon_url TEXT,
        is_private INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE site_permissions (
        origin TEXT NOT NULL,
        permission_type TEXT NOT NULL,
        granted INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (origin, permission_type)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // No migrations yet: schema version 1 is the initial release schema.
    // Future schema changes should add versioned ALTER TABLE steps here,
    // guarded by `if (oldVersion < N) { ... }`.
  }

  Future<void> close() async {
    final Database? db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
