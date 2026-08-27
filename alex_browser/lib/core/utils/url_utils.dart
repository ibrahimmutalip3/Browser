import 'package:alex_browser/core/constants/app_constants.dart';

/// Utilities for interpreting address-bar input, validating URLs, and
/// distinguishing "the user typed a URL" from "the user typed a search
/// query" — the core heuristic behind every browser's smart address bar.
class UrlUtils {
  UrlUtils._();

  static final RegExp _ipv4Pattern = RegExp(
    r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(:\d+)?$',
  );

  // A conservative check for "looks like a domain": at least one dot,
  // valid label characters, and a plausible TLD length.
  static final RegExp _domainLikePattern = RegExp(
    r'^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}(:\d+)?(\/.*)?$',
  );

  /// Returns true if [input] already has an explicit scheme (http://,
  /// https://, tel:, mailto:, etc).
  static bool hasScheme(String input) {
    final RegExpMatch? match = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').firstMatch(input);
    return match != null;
  }

  /// Extracts the scheme (e.g. "https") from a URL string, or null.
  static String? schemeOf(String input) {
    final Uri? uri = Uri.tryParse(input);
    if (uri == null || uri.scheme.isEmpty) return null;
    return uri.scheme;
  }

  /// Heuristically determines whether the given address-bar input should be
  /// treated as a direct URL (navigate) or a search query (search engine).
  ///
  /// This mirrors the logic real browsers use:
  /// - Explicit scheme (https://, ftp://, etc) → always a URL.
  /// - "localhost" or an IPv4/IPv6 literal → a URL.
  /// - Contains a space → almost certainly a search query.
  /// - Looks like "word.tld" or "word.tld/path" with no spaces → a URL.
  /// - Otherwise → a search query.
  static bool looksLikeUrl(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) return false;

    if (hasScheme(trimmed)) return true;

    if (trimmed.contains(' ')) return false;

    if (trimmed == 'localhost' || trimmed.startsWith('localhost:')) return true;
    if (trimmed.startsWith('localhost/')) return true;

    if (_ipv4Pattern.hasMatch(trimmed)) return true;

    // IPv6 literal in brackets.
    if (trimmed.startsWith('[') && trimmed.contains(']')) return true;

    if (_domainLikePattern.hasMatch(trimmed)) return true;

    return false;
  }

  /// Normalizes raw address-bar input into a fully-qualified URL ready to
  /// be loaded by the WebView. Adds "https://" when no scheme is present.
  static String normalizeUrl(String input) {
    final String trimmed = input.trim();

    if (hasScheme(trimmed)) {
      return trimmed;
    }

    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }

    return 'https://$trimmed';
  }

  /// Builds a search-engine query URL for a plain-text query using the
  /// given search engine's query template (e.g.
  /// "https://www.google.com/search?q=%s").
  static String buildSearchUrl(String queryTemplate, String query) {
    final String encoded = Uri.encodeComponent(query.trim());
    return queryTemplate.replaceAll('%s', encoded);
  }

  /// Given raw address-bar text and the active search engine's query
  /// template, returns the final URL to load — either a normalized direct
  /// URL or a search-engine query URL.
  static String resolveAddressBarInput(String input, String searchEngineQueryTemplate) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) return AppConstants.defaultHomepage;

    if (looksLikeUrl(trimmed)) {
      return normalizeUrl(trimmed);
    }

    return buildSearchUrl(searchEngineQueryTemplate, trimmed);
  }

  /// Returns true if [url] uses http or https.
  static bool isWebScheme(String url) {
    final String? scheme = schemeOf(url);
    if (scheme == null) return false;
    return AppConstants.webSchemes.contains(scheme.toLowerCase());
  }

  /// Returns true if [url] is secure (https).
  static bool isSecure(String url) {
    return schemeOf(url)?.toLowerCase() == 'https';
  }

  /// Returns true if [scheme] is one of the recognized external-app schemes
  /// (tel, mailto, intent, etc) that should be handed off to the OS rather
  /// than loaded inside the WebView.
  static bool isExternalScheme(String scheme) {
    return AppConstants.externalSchemes.contains(scheme.toLowerCase());
  }

  /// Extracts a friendly display host from a URL, e.g.
  /// "https://www.example.com/path" -> "example.com".
  static String displayHost(String url) {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    String host = uri.host;
    if (host.startsWith('www.')) {
      host = host.substring(4);
    }
    return host;
  }

  /// Validates that a string is a syntactically well-formed, loadable URL.
  static bool isValidUrl(String url) {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme.isEmpty) return false;
    if (isWebScheme(url) && uri.host.isEmpty) return false;
    return true;
  }
}
