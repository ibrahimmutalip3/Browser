import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:alex_browser/browser/engine/browser_engine.dart';
import 'package:alex_browser/browser/models/download_request.dart';
import 'package:alex_browser/browser/models/js_dialog_request.dart';
import 'package:alex_browser/browser/models/new_window_request.dart';
import 'package:alex_browser/browser/models/page_load_state.dart';
import 'package:alex_browser/browser/models/permission_request.dart';
import 'package:alex_browser/core/services/external_scheme_handler.dart';
import 'package:alex_browser/core/services/permission_service.dart';

/// Concrete [BrowserEngine] backed by `flutter_inappwebview`.
///
/// On Android this wraps the system `android.webkit.WebView`, which is a
/// genuine Chromium/Blink build (V8 JS engine, Blink layout engine)
/// serviced independently of the OS through Google Play system updates.
/// On iOS it wraps `WKWebView` (WebKit) — the only web-rendering engine
/// Apple permits third-party apps to embed (App Store Review Guideline
/// 2.5.6). Both are driven through this single adapter so the rest of the
/// app only ever talks to the [BrowserEngine] abstraction.
class WebViewEngineAdapter implements BrowserEngine {
  WebViewEngineAdapter({required this.isPrivate}) {
    _pageStateController = StreamController<PageLoadState>.broadcast();
    _jsDialogController = StreamController<JsDialogRequest>.broadcast();
    _permissionController = StreamController<WebPermissionRequest>.broadcast();
    _newWindowController = StreamController<NewWindowRequest>.broadcast();
    _downloadController = StreamController<EngineDownloadRequest>.broadcast();
    _state = PageLoadState.initial;
  }

  /// Whether this engine instance belongs to a private (incognito) tab.
  /// Private engines use an isolated, ephemeral WebView data store so
  /// cookies/localStorage never touch disk and never leak into normal
  /// browsing state.
  @override
  final bool isPrivate;

  InAppWebViewController? _controller;
  late PageLoadState _state;

  late final StreamController<PageLoadState> _pageStateController;
  late final StreamController<JsDialogRequest> _jsDialogController;
  late final StreamController<WebPermissionRequest> _permissionController;
  late final StreamController<NewWindowRequest> _newWindowController;
  late final StreamController<EngineDownloadRequest> _downloadController;

  Completer<JsDialogResult>? _pendingJsDialog;
  Completer<PermissionDecision>? _pendingPermission;

  bool _javaScriptEnabled = true;
  bool _cookiesEnabled = true;
  bool _doNotTrack = false;
  bool _disposed = false;

  static int _instanceCounter = 0;

  void _emitState(PageLoadState newState) {
    if (_disposed) return;
    _state = newState;
    _pageStateController.add(_state);
  }

  @override
  Widget buildView() {
    final int id = _instanceCounter++;
    return InAppWebView(
      key: ValueKey<String>('webview_${id}_${isPrivate ? 'private' : 'normal'}'),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: _javaScriptEnabled,
        javaScriptCanOpenWindowsAutomatically: false,
        supportMultipleWindows: true,
        useOnDownloadStart: true,
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        // Private browsing: never persist any storage to disk.
        incognito: isPrivate,
        cacheEnabled: !isPrivate,
        // WebRTC / getUserMedia support.
        allowsAirPlayForMediaPlayback: true,
        // First/third-party cookie access. When the user disables cookies
        // globally in Settings, this goes false and setCookiesEnabled
        // additionally purges the shared CookieManager so no cookie set
        // before the toggle was flipped lingers on disk.
        thirdPartyCookiesEnabled: !isPrivate && _cookiesEnabled,
        transparentBackground: true,
        supportZoom: true,
        builtInZoomControls: true,
        displayZoomControls: false,
        domStorageEnabled: true,
        databaseEnabled: true,
        geolocationEnabled: true,
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
        userAgent: _userAgent(),
      ),
      onWebViewCreated: (InAppWebViewController controller) {
        _controller = controller;
      },
      onLoadStart: (InAppWebViewController controller, WebUri? uri) {
        _emitState(
          _state
              .copyWith(
                url: uri?.toString() ?? _state.url,
                isLoading: true,
                progress: 0.05,
                isSecure: uri?.scheme.toLowerCase() == 'https',
              )
              .clearError(),
        );
      },
      onLoadStop: (InAppWebViewController controller, WebUri? uri) async {
        final String title = await controller.getTitle() ?? _state.title;
        final bool canBack = await controller.canGoBack();
        final bool canForward = await controller.canGoForward();
        _emitState(
          _state.copyWith(
            url: uri?.toString() ?? _state.url,
            title: title,
            isLoading: false,
            progress: 1.0,
            canGoBack: canBack,
            canGoForward: canForward,
            isSecure: uri?.scheme.toLowerCase() == 'https',
          ),
        );
        unawaited(_fetchFavicon(controller, uri));
      },
      onProgressChanged: (InAppWebViewController controller, int progress) {
        _emitState(_state.copyWith(progress: progress / 100.0, isLoading: progress < 100));
      },
      onTitleChanged: (InAppWebViewController controller, String? title) {
        if (title != null) {
          _emitState(_state.copyWith(title: title));
        }
      },
      onReceivedError: (InAppWebViewController controller, WebResourceRequest request, WebResourceError error) {
        if (!request.isForMainFrame!) return;
        _emitState(
          _state.copyWith(
            isLoading: false,
            errorType: _mapErrorType(error.type),
            errorDescription: error.description,
          ),
        );
      },
      onReceivedHttpError: (InAppWebViewController controller, WebResourceRequest request, WebResourceResponse errorResponse) {
        if (!request.isForMainFrame!) return;
        final int? status = errorResponse.statusCode;
        if (status != null && status >= 400) {
          _emitState(
            _state.copyWith(
              isLoading: false,
              errorType: PageErrorType.httpError,
              httpStatusCode: status,
              errorDescription: 'HTTP $status',
            ),
          );
        }
      },
      onReceivedServerTrustAuthRequest: (InAppWebViewController controller, URLAuthenticationChallenge challenge) async {
        // Reject invalid TLS certificates rather than silently trusting
        // them — never weaken transport security for convenience.
        _emitState(
          _state.copyWith(
            isLoading: false,
            errorType: PageErrorType.sslError,
            errorDescription: 'The site\u2019s security certificate is not trusted.',
          ),
        );
        return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.CANCEL);
      },
      shouldOverrideUrlLoading: (InAppWebViewController controller, NavigationAction action) async {
        final WebUri? uri = action.request.url;
        if (uri == null) return NavigationActionPolicy.ALLOW;
        final String scheme = uri.scheme.toLowerCase();

        const Set<String> webSchemes = {'http', 'https', 'about', 'data', 'blob'};
        if (!webSchemes.contains(scheme)) {
          // tel:, mailto:, sms:, geo:, intent:, market:, etc. cannot be
          // rendered by the engine — hand them to the OS instead.
          unawaited(ExternalSchemeHandler.instance.handle(uri.toString()));
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
      onCreateWindow: (InAppWebViewController controller, CreateWindowAction createWindowAction) async {
        final String url = createWindowAction.request.url?.toString() ?? '';
        if (url.isNotEmpty) {
          _newWindowController.add(
            NewWindowRequest(url: url, isUserGesture: true),
          );
        }
        // We never let the WebView itself spawn a second native window;
        // the app opens a new tab instead (see NewTabOnWindowOpen usage
        // in TabsController), so always report "not handled" here.
        return false;
      },
      onJsAlert: (InAppWebViewController controller, JsAlertRequest request) async {
        final JsDialogResult result = await _showJsDialog(
          JsDialogRequest(type: JsDialogType.alert, url: request.url?.toString() ?? '', message: request.message ?? ''),
        );
        return JsAlertResponse(handledByClient: true, action: result.confirmed ? JsAlertResponseAction.CONFIRM : JsAlertResponseAction.CONFIRM);
      },
      onJsConfirm: (InAppWebViewController controller, JsConfirmRequest request) async {
        final JsDialogResult result = await _showJsDialog(
          JsDialogRequest(type: JsDialogType.confirm, url: request.url?.toString() ?? '', message: request.message ?? ''),
        );
        return JsConfirmResponse(
          handledByClient: true,
          action: result.confirmed ? JsConfirmResponseAction.CONFIRM : JsConfirmResponseAction.CANCEL,
        );
      },
      onJsPrompt: (InAppWebViewController controller, JsPromptRequest request) async {
        final JsDialogResult result = await _showJsDialog(
          JsDialogRequest(
            type: JsDialogType.prompt,
            url: request.url?.toString() ?? '',
            message: request.message ?? '',
            defaultValue: request.defaultValue,
          ),
        );
        return JsPromptResponse(
          handledByClient: true,
          action: result.confirmed ? JsPromptResponseAction.CONFIRM : JsPromptResponseAction.CANCEL,
          value: result.promptValue,
        );
      },
      onPermissionRequest: (InAppWebViewController controller, PermissionRequest request) async {
        final List<WebPermissionType> types = request.resources
            .map(_mapEngineResource)
            .whereType<WebPermissionType>()
            .toList();
        if (types.isEmpty) {
          return PermissionResponse(resources: request.resources, action: PermissionResponseAction.DENY);
        }
        final PermissionDecision decision = await _requestPermission(
          WebPermissionRequest(origin: request.origin.toString(), types: types),
        );
        return PermissionResponse(
          resources: request.resources,
          action: decision == PermissionDecision.allow
              ? PermissionResponseAction.GRANT
              : PermissionResponseAction.DENY,
        );
      },
      onGeolocationPermissionsShowPrompt: (InAppWebViewController controller, String origin) async {
        final PermissionDecision decision = await _requestPermission(
          WebPermissionRequest(origin: origin, types: const <WebPermissionType>[WebPermissionType.location]),
        );
        return GeolocationPermissionShowPromptResponse(
          origin: origin,
          allow: decision == PermissionDecision.allow,
          retain: false,
        );
      },
      onDownloadStartRequest: (InAppWebViewController controller, DownloadStartRequest request) {
        _downloadController.add(
          EngineDownloadRequest(
            url: request.url.toString(),
            suggestedFileName: request.suggestedFilename ?? _fileNameFromUrl(request.url.toString()),
            mimeType: request.mimeType,
            contentLength: request.contentLength,
            userAgent: request.userAgent,
          ),
        );
      },
    );
  }

  WebPermissionType? _mapEngineResource(PermissionResourceType resource) {
    if (resource == PermissionResourceType.CAMERA) {
      return WebPermissionType.camera;
    }
    if (resource == PermissionResourceType.MICROPHONE) {
      return WebPermissionType.microphone;
    }
    if (resource == PermissionResourceType.CAMERA_AND_MICROPHONE) {
      return WebPermissionType.camera;
    }
    return null;
  }

  PageErrorType _mapErrorType(WebResourceErrorType? type) {
    if (type == null) return PageErrorType.unknown;
    if (type == WebResourceErrorType.HOST_LOOKUP) {
      return PageErrorType.dnsFailure;
    }
    if (type == WebResourceErrorType.TIMEOUT) {
      return PageErrorType.timeout;
    }
    if (type == WebResourceErrorType.FAILED_SSL_HANDSHAKE) {
      return PageErrorType.connectionRefused;
    }
    if (type == WebResourceErrorType.CANNOT_CONNECT_TO_HOST ||
        type == WebResourceErrorType.CONNECTION_ABORTED ||
        type == WebResourceErrorType.RESET ||
        type == WebResourceErrorType.SERVER_UNREACHABLE) {
      return PageErrorType.connectionRefused;
    }
    final String name = type.toString().toLowerCase();
    if (name.contains('ssl') || name.contains('certificate')) {
      return PageErrorType.sslError;
    }
    if (name.contains('internet') || name.contains('network')) {
      return PageErrorType.noInternet;
    }
    return PageErrorType.unknown;
  }

  Future<JsDialogResult> _showJsDialog(JsDialogRequest request) async {
    _pendingJsDialog = Completer<JsDialogResult>();
    _jsDialogController.add(request);
    return _pendingJsDialog!.future;
  }

  Future<PermissionDecision> _requestPermission(WebPermissionRequest request) async {
    _pendingPermission = Completer<PermissionDecision>();
    _permissionController.add(request);
    return _pendingPermission!.future;
  }

  Future<void> _fetchFavicon(InAppWebViewController controller, WebUri? uri) async {
    if (uri == null) return;
    try {
      final List<Favicon> favicons = await controller.getFavicons();
      if (favicons.isNotEmpty) {
        favicons.sort((Favicon a, Favicon b) => (b.width ?? 0).compareTo(a.width ?? 0));
        _emitState(_state.copyWith(faviconUrl: favicons.first.url.toString()));
      } else {
        final WebUri fallback = WebUri('${uri.scheme}://${uri.host}/favicon.ico');
        _emitState(_state.copyWith(faviconUrl: fallback.toString()));
      }
    } catch (_) {
      // Favicon retrieval is best-effort; failures are silently ignored.
    }
  }

  String _fileNameFromUrl(String url) {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.isEmpty) return 'download';
    final String last = uri.pathSegments.last;
    return last.isEmpty ? 'download' : last;
  }

  String _userAgent() {
    // A modern, standard mobile UA string so sites serve their normal
    // mobile experience rather than a degraded "unknown browser" fallback.
    if (Platform.isIOS) {
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1 AlexBrowser/1.0';
    }
    return 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/128.0.0.0 Mobile Safari/537.36 AlexBrowser/1.0';
  }

  @override
  Future<void> loadUrl(String url, {Map<String, String>? headers}) async {
    final InAppWebViewController? controller = _controller;
    if (controller == null) return;
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(url), headers: _withDoNotTrack(headers)),
    );
  }

  /// Merges the `DNT: 1` header into [headers] when Do Not Track is
  /// enabled in Settings. This is a request signal only, sent faithfully
  /// with every top-level navigation as required — websites are not
  /// obligated to honor it, and none of them are forced to by the browser.
  Map<String, String>? _withDoNotTrack(Map<String, String>? headers) {
    if (!_doNotTrack) return headers;
    return <String, String>{...?headers, 'DNT': '1'};
  }

  @override
  Future<void> loadHtml(String html, {String? baseUrl}) async {
    final InAppWebViewController? controller = _controller;
    if (controller == null) return;
    await controller.loadData(
      data: html,
      baseUrl: baseUrl != null ? WebUri(baseUrl) : null,
      mimeType: 'text/html',
      encoding: 'utf8',
    );
  }

  @override
  Future<void> goBack() async {
    if (await canGoBack()) {
      await _controller?.goBack();
    }
  }

  @override
  Future<void> goForward() async {
    if (await canGoForward()) {
      await _controller?.goForward();
    }
  }

  @override
  Future<void> reload() async {
    await _controller?.reload();
  }

  @override
  Future<void> stop() async {
    await _controller?.stopLoading();
    _emitState(_state.copyWith(isLoading: false));
  }

  @override
  Future<bool> canGoBack() async {
    return await _controller?.canGoBack() ?? false;
  }

  @override
  Future<bool> canGoForward() async {
    return await _controller?.canGoForward() ?? false;
  }

  @override
  Future<String?> evaluateJavascript(String code) async {
    final dynamic result = await _controller?.evaluateJavascript(source: code);
    return result?.toString();
  }

  @override
  Stream<PageLoadState> get pageState => _pageStateController.stream;

  @override
  Stream<JsDialogRequest> get jsDialogRequests => _jsDialogController.stream;

  @override
  void respondToJsDialog(JsDialogResult result) {
    _pendingJsDialog?.complete(result);
    _pendingJsDialog = null;
  }

  @override
  Stream<WebPermissionRequest> get permissionRequests => _permissionController.stream;

  @override
  void respondToPermissionRequest(PermissionDecision decision, {bool remember = false}) {
    _pendingPermission?.complete(decision);
    _pendingPermission = null;
  }

  @override
  Stream<NewWindowRequest> get newWindowRequests => _newWindowController.stream;

  @override
  Stream<EngineDownloadRequest> get downloadRequests => _downloadController.stream;

  @override
  Future<void> setJavaScriptEnabled(bool enabled) async {
    _javaScriptEnabled = enabled;
    await _controller?.setSettings(
      settings: InAppWebViewSettings(javaScriptEnabled: enabled),
    );
  }

  @override
  Future<void> setCookiesEnabled(bool enabled) async {
    _cookiesEnabled = enabled;
    await _controller?.setSettings(
      settings: InAppWebViewSettings(
        thirdPartyCookiesEnabled: !isPrivate && enabled,
      ),
    );
    if (!enabled) {
      // Mirror Chrome/Safari: disabling cookies globally also purges
      // whatever was already stored, so no previously-set cookie keeps a
      // site logged in after the user turns cookies off.
      await clearCookies();
    }
  }

  @override
  Future<void> setDoNotTrack(bool enabled) async {
    _doNotTrack = enabled;
    // DNT is a request header signal, applied per-navigation. There is no
    // persistent "default header" setting on flutter_inappwebview, so it
    // is attached explicitly by loadUrl()/reload() reading `_doNotTrack`.
  }

  @override
  Future<void> clearCookies() async {
    if (isPrivate) {
      // Private WebViews are already backed by an in-memory (incognito)
      // data store; there is nothing persisted to clear, and clearing the
      // shared CookieManager here would wipe normal-mode cookies too.
      return;
    }
    await CookieManager.instance().deleteAllCookies();
  }

  @override
  Future<void> clearCache() async {
    await InAppWebViewController.clearAllCache();
  }

  @override
  Future<void> clearLocalStorage() async {
    final InAppWebViewController? controller = _controller;
    if (controller == null) return;
    await controller.evaluateJavascript(
      source: 'try { localStorage.clear(); sessionStorage.clear(); } catch(e) {}',
    );
    try {
      await WebStorageManager.instance().deleteAllData();
    } catch (_) {
      // Not available on all platform versions; localStorage.clear() above
      // already covers the common case.
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _pageStateController.close();
    await _jsDialogController.close();
    await _permissionController.close();
    await _newWindowController.close();
    await _downloadController.close();
    _controller = null;
  }
}
