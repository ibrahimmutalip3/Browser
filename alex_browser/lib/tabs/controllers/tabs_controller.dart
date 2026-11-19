import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:alex_browser/browser/engine/browser_engine.dart';
import 'package:alex_browser/browser/engine/webview_engine_adapter.dart';
import 'package:alex_browser/browser/models/download_request.dart';
import 'package:alex_browser/browser/models/js_dialog_request.dart';
import 'package:alex_browser/browser/models/new_window_request.dart';
import 'package:alex_browser/browser/models/page_load_state.dart';
import 'package:alex_browser/browser/models/permission_request.dart';
import 'package:alex_browser/browser/repositories/site_permissions_repository.dart';
import 'package:alex_browser/core/constants/app_constants.dart';
import 'package:alex_browser/core/providers/core_providers.dart';
import 'package:alex_browser/core/services/permission_service.dart';
import 'package:alex_browser/core/utils/url_utils.dart';
import 'package:alex_browser/downloads/services/download_manager_service.dart';
import 'package:alex_browser/history/repositories/history_repository.dart';
import 'package:alex_browser/settings/controllers/settings_controller.dart';
import 'package:alex_browser/tabs/models/browser_tab.dart';
import 'package:alex_browser/tabs/repositories/tabs_session_repository.dart';

/// Immutable snapshot of all open tabs plus which one is active.
@immutable
class TabsState {
  const TabsState({required this.tabs, required this.activeTabId});

  final List<BrowserTab> tabs;
  final String? activeTabId;

  BrowserTab? get activeTab {
    if (activeTabId == null) return null;
    for (final BrowserTab tab in tabs) {
      if (tab.id == activeTabId) return tab;
    }
    return null;
  }

  List<BrowserTab> get normalTabs => tabs.where((BrowserTab t) => !t.isPrivate).toList();
  List<BrowserTab> get privateTabs => tabs.where((BrowserTab t) => t.isPrivate).toList();

  static const TabsState empty = TabsState(tabs: <BrowserTab>[], activeTabId: null);

  TabsState copyWith({List<BrowserTab>? tabs, String? activeTabId, bool clearActive = false}) {
    return TabsState(
      tabs: tabs ?? this.tabs,
      activeTabId: clearActive ? null : (activeTabId ?? this.activeTabId),
    );
  }
}

/// A pending native prompt the UI must resolve: a JS dialog or a
/// permission request, surfaced from whichever tab triggered it.
@immutable
sealed class PendingPrompt {
  const PendingPrompt(this.tabId);
  final String tabId;
}

class PendingJsDialogPrompt extends PendingPrompt {
  const PendingJsDialogPrompt(super.tabId, this.request);
  final JsDialogRequest request;
}

class PendingPermissionPrompt extends PendingPrompt {
  const PendingPermissionPrompt(super.tabId, this.request);
  final WebPermissionRequest request;
}

/// Owns every open tab's [BrowserEngine] instance and exposes a reactive
/// [TabsState] to the UI. This is the single source of truth connecting
/// the browser engine layer to tabs, history, downloads, and permissions.
class TabsController extends Notifier<TabsState> {
  final Uuid _uuid = const Uuid();
  final Map<String, BrowserEngine> _engines = <String, BrowserEngine>{};
  final Map<String, StreamSubscription<PageLoadState>> _pageStateSubs = <String, StreamSubscription<PageLoadState>>{};
  final Map<String, StreamSubscription<JsDialogRequest>> _jsDialogSubs = <String, StreamSubscription<JsDialogRequest>>{};
  final Map<String, StreamSubscription<WebPermissionRequest>> _permissionSubs = <String, StreamSubscription<WebPermissionRequest>>{};
  final Map<String, StreamSubscription<NewWindowRequest>> _newWindowSubs = <String, StreamSubscription<NewWindowRequest>>{};
  final Map<String, StreamSubscription<EngineDownloadRequest>> _downloadSubs = <String, StreamSubscription<EngineDownloadRequest>>{};
  final Set<String> _recordedUrlsThisLoad = <String>{};

  final StreamController<PendingPrompt> _promptsController = StreamController<PendingPrompt>.broadcast();
  Stream<PendingPrompt> get prompts => _promptsController.stream;

  late HistoryRepository _historyRepository;
  late DownloadManagerService _downloadManager;
  late TabsSessionRepository _sessionRepository;
  late SitePermissionsRepository _sitePermissionsRepository;

  @override
  TabsState build() {
    _historyRepository = ref.watch(historyRepositoryProvider);
    _downloadManager = ref.watch(downloadManagerServiceProvider);
    _sessionRepository = ref.watch(tabsSessionRepositoryProvider);
    _sitePermissionsRepository = ref.watch(sitePermissionsRepositoryProvider);

    ref.onDispose(() {
      for (final BrowserEngine engine in _engines.values) {
        engine.dispose();
      }
      for (final StreamSubscription<dynamic> sub in <StreamSubscription<dynamic>>[
        ..._pageStateSubs.values,
        ..._jsDialogSubs.values,
        ..._permissionSubs.values,
        ..._newWindowSubs.values,
        ..._downloadSubs.values,
      ]) {
        sub.cancel();
      }
      _promptsController.close();
    });

    return TabsState.empty;
  }

  BrowserEngine? engineFor(String tabId) => _engines[tabId];

  /// Restores the previous normal-tab session (if any and if enabled in
  /// Settings), or opens a single fresh tab at the homepage. Called once
  /// from the root widget's initState-equivalent.
  Future<void> restoreOrCreateInitial() async {
    final bool restore = ref.read(settingsControllerProvider).restoreTabsOnStart;
    if (restore) {
      final List<BrowserTab> restored = await _sessionRepository.restoreSession();
      if (restored.isNotEmpty) {
        final String? activeId = await _sessionRepository.restoreActiveTabId();
        for (final BrowserTab tab in restored) {
          _createEngineFor(tab);
        }
        state = TabsState(tabs: restored, activeTabId: activeId ?? restored.first.id);
        for (final BrowserTab tab in restored) {
          final BrowserEngine? engine = _engines[tab.id];
          if (engine != null && tab.url.isNotEmpty) {
            unawaited(engine.loadUrl(tab.url));
          }
        }
        return;
      }
    }
    await openNewTab(isPrivate: false, url: ref.read(settingsControllerProvider).homepage);
  }

  void _createEngineFor(BrowserTab tab) {
    final WebViewEngineAdapter engine = WebViewEngineAdapter(isPrivate: tab.isPrivate);
    _engines[tab.id] = engine;
    _wireEngine(tab.id, engine);

    // New engines must start with the user's current content settings
    // rather than hardcoded defaults, so a tab opened after the user
    // disabled JavaScript/cookies or enabled Do Not Track respects that
    // choice immediately instead of only after the next global toggle.
    final SettingsState settings = ref.read(settingsControllerProvider);
    unawaited(engine.setJavaScriptEnabled(settings.javaScriptEnabled));
    unawaited(engine.setCookiesEnabled(settings.cookiesEnabled));
    unawaited(engine.setDoNotTrack(settings.doNotTrack));
  }

  void _wireEngine(String tabId, BrowserEngine engine) {
    _pageStateSubs[tabId] = engine.pageState.listen((PageLoadState newState) {
      _updateTabState(tabId, newState);
    });

    _jsDialogSubs[tabId] = engine.jsDialogRequests.listen((JsDialogRequest request) {
      _promptsController.add(PendingJsDialogPrompt(tabId, request));
    });

    _permissionSubs[tabId] = engine.permissionRequests.listen((WebPermissionRequest request) async {
      final bool? remembered = await _lookupRememberedPermission(request);
      if (remembered != null) {
        engine.respondToPermissionRequest(remembered ? PermissionDecision.allow : PermissionDecision.deny);
        return;
      }
      _promptsController.add(PendingPermissionPrompt(tabId, request));
    });

    _newWindowSubs[tabId] = engine.newWindowRequests.listen((NewWindowRequest request) {
      final bool popupsBlocked = ref.read(settingsControllerProvider).popupsBlocked;
      // User-gesture-driven window.open() (e.g. OAuth popups) is always
      // allowed even when popup blocking is on; only script-initiated,
      // non-gesture popups are subject to blocking.
      if (popupsBlocked && !request.isUserGesture) {
        return;
      }
      final bool isPrivate = _engines[tabId]?.isPrivate ?? false;
      unawaited(openNewTab(isPrivate: isPrivate, url: request.url, makeActive: request.isUserGesture));
    });

    _downloadSubs[tabId] = engine.downloadRequests.listen((EngineDownloadRequest request) {
      unawaited(_downloadManager.startDownload(request));
    });
  }

  Future<bool?> _lookupRememberedPermission(WebPermissionRequest request) async {
    // If any requested type was previously denied, deny outright. If all
    // requested types were previously granted, allow outright. Otherwise
    // (mixed / unknown), fall through to prompting.
    bool allKnownGranted = true;
    for (final WebPermissionType type in request.types) {
      final bool? decision = await _sitePermissionsRepository.lookup(origin: request.origin, type: type);
      if (decision == null) return null;
      if (decision == false) return false;
      allKnownGranted = allKnownGranted && decision;
    }
    return allKnownGranted;
  }

  void _updateTabState(String tabId, PageLoadState newState) {
    final List<BrowserTab> updated = state.tabs.map((BrowserTab tab) {
      if (tab.id != tabId) return tab;
      return tab.copyWith(pageState: newState);
    }).toList();
    state = state.copyWith(tabs: updated);

    BrowserTab? tab;
    for (final BrowserTab t in updated) {
      if (t.id == tabId) {
        tab = t;
        break;
      }
    }
    if (tab == null) return;

    // Record history once per completed, non-error, non-private load.
    if (!tab.isPrivate && !newState.isLoading && !newState.hasError && newState.url.isNotEmpty) {
      final String key = '$tabId::${newState.url}';
      if (!_recordedUrlsThisLoad.contains(key)) {
        _recordedUrlsThisLoad.add(key);
        unawaited(
          _historyRepository.recordVisit(
            url: newState.url,
            title: newState.title,
            faviconUrl: newState.faviconUrl,
          ),
        );
      }
    }
    if (newState.isLoading) {
      _recordedUrlsThisLoad.removeWhere((String k) => k.startsWith('$tabId::'));
    }

    unawaited(_persistSession());
  }

  Future<void> openNewTab({required bool isPrivate, String? url, bool makeActive = true}) async {
    final BrowserTab tab = BrowserTab(
      id: _uuid.v4(),
      isPrivate: isPrivate,
      createdAt: DateTime.now(),
    );
    _createEngineFor(tab);

    final List<BrowserTab> updatedTabs = <BrowserTab>[...state.tabs, tab];
    state = state.copyWith(
      tabs: updatedTabs,
      activeTabId: makeActive ? tab.id : state.activeTabId,
    );

    final String targetUrl = url ?? ref.read(settingsControllerProvider).homepage;
    final BrowserEngine? engine = _engines[tab.id];
    if (engine != null && targetUrl != AppConstants.newTabUrl) {
      await engine.loadUrl(targetUrl);
    }
    await _persistSession();
  }

  Future<void> closeTab(String tabId) async {
    final BrowserEngine? engine = _engines.remove(tabId);
    await engine?.dispose();
    await _pageStateSubs.remove(tabId)?.cancel();
    await _jsDialogSubs.remove(tabId)?.cancel();
    await _permissionSubs.remove(tabId)?.cancel();
    await _newWindowSubs.remove(tabId)?.cancel();
    await _downloadSubs.remove(tabId)?.cancel();

    final List<BrowserTab> remaining = state.tabs.where((BrowserTab t) => t.id != tabId).toList();
    String? newActiveId = state.activeTabId;
    if (state.activeTabId == tabId) {
      newActiveId = remaining.isNotEmpty ? remaining.last.id : null;
    }
    state = TabsState(tabs: remaining, activeTabId: newActiveId);

    if (remaining.isEmpty) {
      await openNewTab(isPrivate: false, url: ref.read(settingsControllerProvider).homepage);
    } else {
      await _persistSession();
    }
  }

  Future<void> closeAllPrivateTabs() async {
    final List<BrowserTab> privateTabs = state.privateTabs;
    for (final BrowserTab tab in privateTabs) {
      await closeTab(tab.id);
    }
  }

  void setActiveTab(String tabId) {
    state = state.copyWith(activeTabId: tabId);
  }

  Future<void> navigateActiveTab(String rawInput) async {
    final BrowserTab? tab = state.activeTab;
    if (tab == null) return;
    final BrowserEngine? engine = _engines[tab.id];
    if (engine == null) return;

    final String template = ref.read(settingsControllerProvider).searchEngine.queryTemplate;
    final String resolved = UrlUtils.resolveAddressBarInput(rawInput, template);
    await engine.loadUrl(resolved);
  }

  Future<void> reloadActiveTab() async {
    await _engines[state.activeTabId]?.reload();
  }

  Future<void> stopActiveTab() async {
    await _engines[state.activeTabId]?.stop();
  }

  Future<void> goBackActiveTab() async {
    await _engines[state.activeTabId]?.goBack();
  }

  Future<void> goForwardActiveTab() async {
    await _engines[state.activeTabId]?.goForward();
  }

  void resolveJsDialog(String tabId, JsDialogResult result) {
    _engines[tabId]?.respondToJsDialog(result);
  }

  Future<void> resolvePermission(
    String tabId,
    WebPermissionRequest request,
    PermissionDecision decision, {
    bool remember = false,
  }) async {
    _engines[tabId]?.respondToPermissionRequest(decision, remember: remember);
    if (remember) {
      for (final WebPermissionType type in request.types) {
        await _sitePermissionsRepository.remember(
          origin: request.origin,
          type: type,
          granted: decision == PermissionDecision.allow,
        );
      }
    }
  }

  Future<void> _persistSession() async {
    await _sessionRepository.saveSession(state.normalTabs, activeTabId: state.activeTabId);
  }

  Future<void> applyJavaScriptEnabled(bool enabled) async {
    for (final BrowserEngine engine in _engines.values) {
      await engine.setJavaScriptEnabled(enabled);
    }
  }

  /// Applies a global cookies on/off toggle to every currently open engine.
  /// Mirrors [applyJavaScriptEnabled] — see Settings > Cookies.
  Future<void> applyCookiesEnabled(bool enabled) async {
    for (final BrowserEngine engine in _engines.values) {
      await engine.setCookiesEnabled(enabled);
    }
  }

  /// Applies a global Do Not Track toggle to every currently open engine.
  /// See Settings > Do Not Track.
  Future<void> applyDoNotTrack(bool enabled) async {
    for (final BrowserEngine engine in _engines.values) {
      await engine.setDoNotTrack(enabled);
    }
  }

  /// Clears browsing data across all currently open engines and, for
  /// history/cookies-wide clears, the persisted stores too. Used by
  /// Settings > Clear Browsing Data.
  Future<void> clearBrowsingData({
    required bool clearHistory,
    required bool clearCookies,
    required bool clearCache,
    required bool clearLocalStorage,
  }) async {
    for (final BrowserEngine engine in _engines.values) {
      if (clearCookies) await engine.clearCookies();
      if (clearCache) await engine.clearCache();
      if (clearLocalStorage) await engine.clearLocalStorage();
    }
    if (clearHistory) {
      await _historyRepository.clearAll();
    }
  }
}

final NotifierProvider<TabsController, TabsState> tabsControllerProvider =
    NotifierProvider<TabsController, TabsState>(TabsController.new);
