import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alex_browser/core/providers/core_providers.dart';
import 'package:alex_browser/core/services/preferences_service.dart';
import 'package:alex_browser/settings/models/search_engine.dart';

/// Immutable snapshot of all user-configurable browser settings, kept in
/// sync with [PreferencesService] (SharedPreferences-backed storage).
@immutable
class SettingsState {
  const SettingsState({
    required this.searchEngine,
    required this.homepage,
    required this.themeMode,
    required this.javaScriptEnabled,
    required this.popupsBlocked,
    required this.cookiesEnabled,
    required this.doNotTrack,
    required this.restoreTabsOnStart,
  });

  final SearchEngine searchEngine;
  final String homepage;
  final ThemeMode themeMode;
  final bool javaScriptEnabled;
  final bool popupsBlocked;
  final bool cookiesEnabled;
  final bool doNotTrack;
  final bool restoreTabsOnStart;

  SettingsState copyWith({
    SearchEngine? searchEngine,
    String? homepage,
    ThemeMode? themeMode,
    bool? javaScriptEnabled,
    bool? popupsBlocked,
    bool? cookiesEnabled,
    bool? doNotTrack,
    bool? restoreTabsOnStart,
  }) {
    return SettingsState(
      searchEngine: searchEngine ?? this.searchEngine,
      homepage: homepage ?? this.homepage,
      themeMode: themeMode ?? this.themeMode,
      javaScriptEnabled: javaScriptEnabled ?? this.javaScriptEnabled,
      popupsBlocked: popupsBlocked ?? this.popupsBlocked,
      cookiesEnabled: cookiesEnabled ?? this.cookiesEnabled,
      doNotTrack: doNotTrack ?? this.doNotTrack,
      restoreTabsOnStart: restoreTabsOnStart ?? this.restoreTabsOnStart,
    );
  }
}

ThemeMode _themeModeFromRaw(String raw) {
  switch (raw) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

String _rawFromThemeMode(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

class SettingsController extends Notifier<SettingsState> {
  late final PreferencesService _prefs;

  @override
  SettingsState build() {
    _prefs = ref.watch(preferencesServiceProvider);
    return SettingsState(
      searchEngine: SearchEngine.byId(_prefs.searchEngineId),
      homepage: _prefs.homepage,
      themeMode: _themeModeFromRaw(_prefs.themeModeRaw),
      javaScriptEnabled: _prefs.javaScriptEnabled,
      popupsBlocked: _prefs.popupsBlocked,
      cookiesEnabled: _prefs.cookiesEnabled,
      doNotTrack: _prefs.doNotTrack,
      restoreTabsOnStart: _prefs.restoreTabsOnStart,
    );
  }

  Future<void> setSearchEngine(SearchEngine engine) async {
    await _prefs.setSearchEngineId(engine.id);
    state = state.copyWith(searchEngine: engine);
  }

  Future<void> setHomepage(String url) async {
    await _prefs.setHomepage(url);
    state = state.copyWith(homepage: url);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setThemeModeRaw(_rawFromThemeMode(mode));
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setJavaScriptEnabled(bool value) async {
    await _prefs.setJavaScriptEnabled(value);
    state = state.copyWith(javaScriptEnabled: value);
  }

  Future<void> setPopupsBlocked(bool value) async {
    await _prefs.setPopupsBlocked(value);
    state = state.copyWith(popupsBlocked: value);
  }

  Future<void> setCookiesEnabled(bool value) async {
    await _prefs.setCookiesEnabled(value);
    state = state.copyWith(cookiesEnabled: value);
  }

  Future<void> setDoNotTrack(bool value) async {
    await _prefs.setDoNotTrack(value);
    state = state.copyWith(doNotTrack: value);
  }

  Future<void> setRestoreTabsOnStart(bool value) async {
    await _prefs.setRestoreTabsOnStart(value);
    state = state.copyWith(restoreTabsOnStart: value);
  }
}

final NotifierProvider<SettingsController, SettingsState> settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
