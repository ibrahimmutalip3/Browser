import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alex_browser/browser/repositories/site_permissions_repository.dart';
import 'package:alex_browser/bookmarks/repositories/bookmarks_repository.dart';
import 'package:alex_browser/core/services/preferences_service.dart';
import 'package:alex_browser/downloads/repositories/downloads_repository.dart';
import 'package:alex_browser/downloads/services/download_manager_service.dart';
import 'package:alex_browser/history/repositories/history_repository.dart';
import 'package:alex_browser/tabs/repositories/tabs_session_repository.dart';

/// Provides the singleton [PreferencesService]. Must be overridden in
/// `main()` with the already-initialized instance via
/// `ProviderScope(overrides: [preferencesServiceProvider.overrideWithValue(...)])`
/// since initialization is asynchronous and must complete before runApp.
final Provider<PreferencesService> preferencesServiceProvider = Provider<PreferencesService>(
  (Ref ref) => throw UnimplementedError('preferencesServiceProvider must be overridden in main()'),
);

final Provider<HistoryRepository> historyRepositoryProvider = Provider<HistoryRepository>(
  (Ref ref) => HistoryRepository(),
);

final Provider<BookmarksRepository> bookmarksRepositoryProvider = Provider<BookmarksRepository>(
  (Ref ref) => BookmarksRepository(),
);

final Provider<DownloadsRepository> downloadsRepositoryProvider = Provider<DownloadsRepository>(
  (Ref ref) => DownloadsRepository(),
);

final Provider<TabsSessionRepository> tabsSessionRepositoryProvider = Provider<TabsSessionRepository>(
  (Ref ref) => TabsSessionRepository(),
);

final Provider<SitePermissionsRepository> sitePermissionsRepositoryProvider =
    Provider<SitePermissionsRepository>((Ref ref) => SitePermissionsRepository());

/// Long-lived download manager: kept alive for the whole app session so
/// in-flight downloads survive navigation between screens.
final Provider<DownloadManagerService> downloadManagerServiceProvider = Provider<DownloadManagerService>(
  (Ref ref) {
    final DownloadManagerService service = DownloadManagerService(
      repository: ref.watch(downloadsRepositoryProvider),
    );
    ref.onDispose(service.dispose);
    return service;
  },
);
