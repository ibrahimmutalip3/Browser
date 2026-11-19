/// Global, static constants used throughout Alex Browser.
///
/// Keeping these centralized avoids hardcoding values (like a specific
/// search engine or homepage) in multiple places across the codebase.
library;

class AppConstants {
  AppConstants._();

  static const String appName = 'Alex Browser';

  /// Default homepage shown when a new tab is opened with no other URL.
  static const String defaultHomepage = 'https://www.google.com';

  /// Fallback URL used when a user enters a bare search term instead of a URL.
  static const String defaultSearchEngineId = 'google';

  /// Local, bundled page shown for brand-new empty tabs (start page).
  static const String newTabUrl = 'about:newtab';

  /// Maximum number of tabs allowed to keep memory usage reasonable on
  /// lower-end devices. WebView instances are relatively expensive.
  static const int maxOpenTabs = 50;

  /// Maximum number of history entries kept before old entries are pruned.
  static const int maxHistoryEntries = 10000;

  /// Database file name for the local SQLite store.
  static const String databaseName = 'alex_browser.db';
  static const int databaseVersion = 1;

  /// SharedPreferences keys.
  static const String prefKeySearchEngine = 'settings.search_engine';
  static const String prefKeyHomepage = 'settings.homepage';
  static const String prefKeyThemeMode = 'settings.theme_mode';
  static const String prefKeyJavaScriptEnabled = 'settings.javascript_enabled';
  static const String prefKeyPopupsBlocked = 'settings.popups_blocked';
  static const String prefKeyCookiesEnabled = 'settings.cookies_enabled';
  static const String prefKeyDoNotTrack = 'settings.do_not_track';
  static const String prefKeyRestoreTabsOnStart = 'settings.restore_tabs_on_start';

  /// URL schemes the browser recognizes and handles specially.
  static const List<String> webSchemes = ['http', 'https'];
  static const List<String> externalSchemes = [
    'tel',
    'mailto',
    'sms',
    'geo',
    'intent',
    'market',
    'whatsapp',
    'facetime',
    'itms-apps',
  ];
}
