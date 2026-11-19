import 'package:equatable/equatable.dart';

/// The kind of error that stopped a page from loading. Used to select the
/// right error page (see ui/screens/error_page.dart).
enum PageErrorType {
  none,
  noInternet,
  dnsFailure,
  timeout,
  connectionRefused,
  sslError,
  invalidUrl,
  httpError,
  unknown,
}

/// Immutable snapshot of a single tab's navigation/loading state at a
/// point in time. Produced by [BrowserEngine] callbacks and stored per-tab
/// in [TabsController].
class PageLoadState extends Equatable {
  const PageLoadState({
    required this.url,
    required this.title,
    required this.isLoading,
    required this.progress,
    required this.canGoBack,
    required this.canGoForward,
    required this.isSecure,
    this.faviconUrl,
    this.errorType = PageErrorType.none,
    this.errorDescription,
    this.httpStatusCode,
  });

  final String url;
  final String title;
  final bool isLoading;

  /// 0.0 - 1.0 loading progress, as reported by the engine.
  final double progress;
  final bool canGoBack;
  final bool canGoForward;
  final bool isSecure;
  final String? faviconUrl;
  final PageErrorType errorType;
  final String? errorDescription;
  final int? httpStatusCode;

  bool get hasError => errorType != PageErrorType.none;

  static const PageLoadState initial = PageLoadState(
    url: '',
    title: '',
    isLoading: false,
    progress: 0,
    canGoBack: false,
    canGoForward: false,
    isSecure: false,
  );

  PageLoadState copyWith({
    String? url,
    String? title,
    bool? isLoading,
    double? progress,
    bool? canGoBack,
    bool? canGoForward,
    bool? isSecure,
    String? faviconUrl,
    PageErrorType? errorType,
    String? errorDescription,
    int? httpStatusCode,
  }) {
    return PageLoadState(
      url: url ?? this.url,
      title: title ?? this.title,
      isLoading: isLoading ?? this.isLoading,
      progress: progress ?? this.progress,
      canGoBack: canGoBack ?? this.canGoBack,
      canGoForward: canGoForward ?? this.canGoForward,
      isSecure: isSecure ?? this.isSecure,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      errorType: errorType ?? this.errorType,
      errorDescription: errorDescription ?? this.errorDescription,
      httpStatusCode: httpStatusCode ?? this.httpStatusCode,
    );
  }

  /// Clears any error state — used when starting a fresh navigation.
  PageLoadState clearError() {
    return copyWith(errorType: PageErrorType.none)
        .copyWithErrorDescription(null)
        .copyWithHttpStatusCode(null);
  }

  // Helper copyWith variants that allow explicitly setting nullable fields
  // to null, since the standard copyWith above treats null as "keep
  // existing value" (the common Dart copyWith limitation).
  PageLoadState copyWithErrorDescription(String? value) {
    return PageLoadState(
      url: url,
      title: title,
      isLoading: isLoading,
      progress: progress,
      canGoBack: canGoBack,
      canGoForward: canGoForward,
      isSecure: isSecure,
      faviconUrl: faviconUrl,
      errorType: errorType,
      errorDescription: value,
      httpStatusCode: httpStatusCode,
    );
  }

  PageLoadState copyWithHttpStatusCode(int? value) {
    return PageLoadState(
      url: url,
      title: title,
      isLoading: isLoading,
      progress: progress,
      canGoBack: canGoBack,
      canGoForward: canGoForward,
      isSecure: isSecure,
      faviconUrl: faviconUrl,
      errorType: errorType,
      errorDescription: errorDescription,
      httpStatusCode: value,
    );
  }

  @override
  List<Object?> get props => [
        url,
        title,
        isLoading,
        progress,
        canGoBack,
        canGoForward,
        isSecure,
        faviconUrl,
        errorType,
        errorDescription,
        httpStatusCode,
      ];
}
