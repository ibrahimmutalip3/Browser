import 'dart:async';

import 'package:url_launcher/url_launcher.dart';


/// Outcome of attempting to hand a non-web URL scheme to the OS, so the UI
/// can show a clear message when nothing on the device can handle it
/// (per requirement #18: "for unsupported schemes, show a clear message").
enum ExternalSchemeResult { launched, unsupported, invalid }

/// Hands off URL schemes the WebView cannot render itself — `tel:`,
/// `mailto:`, `sms:`, `geo:`, `intent:` (Android), `market:`,
/// `whatsapp:`, `facetime:` (iOS), `itms-apps:`, and similar — to the
/// underlying operating system, which routes them to the appropriate
/// native app (Phone, Mail, Maps, Play Store, App Store, etc).
///
/// This never attempts to render such schemes inside the browser engine;
/// that is both technically impossible (they aren't web content) and, for
/// `intent:` on Android, would bypass the OS's own security prompts.
class ExternalSchemeHandler {
  ExternalSchemeHandler._();

  static final ExternalSchemeHandler instance = ExternalSchemeHandler._();

  /// Stream of results, primarily so the UI can show a snackbar/toast when
  /// a scheme has no handler installed on the device.
  final StreamController<ExternalSchemeEvent> _events = StreamController<ExternalSchemeEvent>.broadcast();

  Stream<ExternalSchemeEvent> get events => _events.stream;

  Future<ExternalSchemeResult> handle(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.scheme.isEmpty) {
      _events.add(ExternalSchemeEvent(url, ExternalSchemeResult.invalid));
      return ExternalSchemeResult.invalid;
    }

    // Even schemes outside our enumerated list (UrlUtils.isExternalScheme)
    // still get a best-effort external launch attempt below — this covers
    // device- or vendor-specific schemes (e.g. a banking app's custom
    // scheme) we don't explicitly know about.
    try {
      final bool can = await canLaunchUrl(uri);
      if (!can) {
        _events.add(ExternalSchemeEvent(url, ExternalSchemeResult.unsupported));
        return ExternalSchemeResult.unsupported;
      }
      final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      final ExternalSchemeResult result = launched ? ExternalSchemeResult.launched : ExternalSchemeResult.unsupported;
      _events.add(ExternalSchemeEvent(url, result));
      return result;
    } catch (_) {
      _events.add(ExternalSchemeEvent(url, ExternalSchemeResult.unsupported));
      return ExternalSchemeResult.unsupported;
    }
  }
}

class ExternalSchemeEvent {
  const ExternalSchemeEvent(this.url, this.result);
  final String url;
  final ExternalSchemeResult result;
}
