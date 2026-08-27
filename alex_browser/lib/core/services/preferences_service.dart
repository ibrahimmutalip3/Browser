import 'package:shared_preferences/shared_preferences.dart';

import 'package:alex_browser/core/constants/app_constants.dart';

/// Thin, typed wrapper around [SharedPreferences] for all simple browser
/// settings (search engine, homepage, theme mode, content toggles).
///
/// Must be initialized once at app startup via [PreferencesService.init]
/// before any read/write calls are made.
class PreferencesService {
  PreferencesService._(this._prefs);

  static PreferencesService? _instance;

  final SharedPreferences _prefs;

  static Future<PreferencesService> init() async {
    if (_instance != null) return _instance!;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _instance = PreferencesService._(prefs);
    return _instance!;
  }

  static PreferencesService get instance {
    final PreferencesService? inst = _instance;
    if (inst == null) {
      throw StateError(
        'PreferencesService.init() must be awaited before use (call it in main()).',
      );
    }
    return inst;
  }

  // --- Search engine ---
  String get searchEngineId =>
      _prefs.getString(AppConstants.prefKeySearchEngine) ?? AppConstants.defaultSearchEngineId;

  Future<void> setSearchEngineId(String id) => _prefs.setString(AppConstants.prefKeySearchEngine, id);

  // --- Homepage ---
  String get homepage => _prefs.getString(AppConstants.prefKeyHomepage) ?? AppConstants.defaultHomepage;

  Future<void> setHomepage(String url) => _prefs.setString(AppConstants.prefKeyHomepage, url);

  // --- Theme mode: 'system' | 'light' | 'dark' ---
  String get themeModeRaw => _prefs.getString(AppConstants.prefKeyThemeMode) ?? 'system';

  Future<void> setThemeModeRaw(String mode) => _prefs.setString(AppConstants.prefKeyThemeMode, mode);

  // --- Content settings ---
  bool get javaScriptEnabled => _prefs.getBool(AppConstants.prefKeyJavaScriptEnabled) ?? true;

  Future<void> setJavaScriptEnabled(bool value) =>
      _prefs.setBool(AppConstants.prefKeyJavaScriptEnabled, value);

  bool get popupsBlocked => _prefs.getBool(AppConstants.prefKeyPopupsBlocked) ?? true;

  Future<void> setPopupsBlocked(bool value) => _prefs.setBool(AppConstants.prefKeyPopupsBlocked, value);

  bool get cookiesEnabled => _prefs.getBool(AppConstants.prefKeyCookiesEnabled) ?? true;

  Future<void> setCookiesEnabled(bool value) => _prefs.setBool(AppConstants.prefKeyCookiesEnabled, value);

  bool get doNotTrack => _prefs.getBool(AppConstants.prefKeyDoNotTrack) ?? false;

  Future<void> setDoNotTrack(bool value) => _prefs.setBool(AppConstants.prefKeyDoNotTrack, value);

  bool get restoreTabsOnStart => _prefs.getBool(AppConstants.prefKeyRestoreTabsOnStart) ?? true;

  Future<void> setRestoreTabsOnStart(bool value) =>
      _prefs.setBool(AppConstants.prefKeyRestoreTabsOnStart, value);

  /// Clears all stored preferences, restoring defaults. Used by
  /// "Clear Browsing Data" when the user opts to reset settings too.
  Future<void> clearAll() => _prefs.clear();
}
