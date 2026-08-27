import 'package:flutter/widgets.dart';

import 'package:alex_browser/browser/models/download_request.dart';
import 'package:alex_browser/browser/models/js_dialog_request.dart';
import 'package:alex_browser/browser/models/new_window_request.dart';
import 'package:alex_browser/browser/models/page_load_state.dart';
import 'package:alex_browser/browser/models/permission_request.dart';

/// Abstraction over the platform's actual web rendering engine.
///
/// On Android, the concrete implementation is backed by the system
/// WebView — which, from Android 5.0 (Lollipop) onward, IS a genuine
/// Chromium/Blink engine build maintained by Google and updated
/// independently of the OS via the Play Store. It supports the full
/// modern web platform: HTML5, CSS, JavaScript (V8), cookies,
/// localStorage/sessionStorage, WebSockets, WebRTC, media playback, and
/// more. This is not a simplified or "lite" renderer — it is the same
/// rendering engine family that powers Google Chrome itself.
///
/// On iOS, Apple's App Store policy (guideline 2.5.6) legally requires
/// all web-rendering apps to use WebKit (WKWebView) — no app, including
/// Chrome or Firefox on iOS, is permitted to ship its own Blink or Gecko
/// rendering engine on that platform. WKWebView is Safari's own engine
/// and supports the same broad set of modern web features.
///
/// This interface exists so that:
///   1. The UI layer (tabs, address bar, navigation controls) never
///      depends directly on `flutter_inappwebview` or any other plugin.
///   2. Platform differences are isolated to a single implementation file
///      (see `webview_engine_adapter.dart`).
///   3. The engine could be swapped or mocked in tests without touching
///      any UI code.
abstract class BrowserEngine {
  /// Whether this engine instance belongs to a private (incognito) tab.
  /// Exposed on the abstraction (not just the WebView-specific adapter)
  /// because callers such as [TabsController] need to know this without
  /// downcasting to a concrete implementation.
  bool get isPrivate;

  /// A widget that renders this engine's live web content. Must be
  /// inserted into the widget tree for the engine to become active —
  /// engines are not headless.
  Widget buildView();

  /// Loads [url] in this engine instance, replacing current content.
  Future<void> loadUrl(String url, {Map<String, String>? headers});

  /// Loads raw HTML content directly (used for the offline start page and
  /// custom error pages) with an optional base URL for resolving relative
  /// resources.
  Future<void> loadHtml(String html, {String? baseUrl});

  Future<void> goBack();
  Future<void> goForward();
  Future<void> reload();
  Future<void> stop();

  Future<bool> canGoBack();
  Future<bool> canGoForward();

  /// Executes arbitrary JavaScript in the page context and returns its
  /// string result, if any.
  Future<String?> evaluateJavascript(String code);

  /// Current page URL, title, and loading/error state as a stream so the
  /// UI can react to navigation events (used to drive [PageLoadState] in
  /// TabsController).
  Stream<PageLoadState> get pageState;

  /// Emitted when the page requests a native JS dialog (alert/confirm/
  /// prompt). The UI must show a dialog and call [respondToJsDialog] with
  /// the user's choice.
  Stream<JsDialogRequest> get jsDialogRequests;
  void respondToJsDialog(JsDialogResult result);

  /// Emitted when the page requests a sensitive permission (camera, mic,
  /// location, notifications) via a Web API like getUserMedia().
  Stream<WebPermissionRequest> get permissionRequests;
  void respondToPermissionRequest(PermissionDecision decision, {bool remember = false});

  /// Emitted when the page wants to open a new browsing context
  /// (target="_blank", window.open(), or middle-click on a link).
  Stream<NewWindowRequest> get newWindowRequests;

  /// Emitted when the page or server initiates a file download that the
  /// engine cannot render inline.
  Stream<EngineDownloadRequest> get downloadRequests;

  /// Whether JavaScript execution is currently enabled for this engine
  /// instance.
  Future<void> setJavaScriptEnabled(bool enabled);

  /// Enables or disables cookie storage (first- and third-party) for this
  /// engine instance, mirroring the Settings > Cookies toggle.
  Future<void> setCookiesEnabled(bool enabled);

  /// Applies (or removes) a `DNT: 1` request header sent with every
  /// top-level navigation, mirroring the Settings > Do Not Track toggle.
  /// This is a request signal only — websites are not required to honor
  /// it — but the browser must still send it faithfully when enabled.
  Future<void> setDoNotTrack(bool enabled);

  /// Clears cookies for this engine instance (used by private-mode
  /// teardown and "Clear Browsing Data").
  Future<void> clearCookies();

  /// Clears cache (HTML/CSS/JS/image cache) for this engine instance.
  Future<void> clearCache();

  /// Clears localStorage/sessionStorage/IndexedDB for this engine instance.
  Future<void> clearLocalStorage();

  /// Releases all native resources held by this engine instance. Must be
  /// called when a tab is closed to avoid leaking native WebView memory.
  Future<void> dispose();
}
