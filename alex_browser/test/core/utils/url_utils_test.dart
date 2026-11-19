import 'package:flutter_test/flutter_test.dart';

import 'package:alex_browser/core/utils/url_utils.dart';

void main() {
  group('UrlUtils.looksLikeUrl', () {
    test('recognizes explicit schemes as URLs', () {
      expect(UrlUtils.looksLikeUrl('https://example.com'), isTrue);
      expect(UrlUtils.looksLikeUrl('http://example.com'), isTrue);
      expect(UrlUtils.looksLikeUrl('tel:+15551234567'), isTrue);
    });

    test('recognizes bare domains as URLs', () {
      expect(UrlUtils.looksLikeUrl('example.com'), isTrue);
      expect(UrlUtils.looksLikeUrl('example.com/path'), isTrue);
      expect(UrlUtils.looksLikeUrl('sub.example.co.uk'), isTrue);
    });

    test('recognizes localhost and IP literals as URLs', () {
      expect(UrlUtils.looksLikeUrl('localhost'), isTrue);
      expect(UrlUtils.looksLikeUrl('localhost:8080'), isTrue);
      expect(UrlUtils.looksLikeUrl('192.168.1.1'), isTrue);
    });

    test('treats plain text with spaces as a search query', () {
      expect(UrlUtils.looksLikeUrl('best programming languages'), isFalse);
      expect(UrlUtils.looksLikeUrl('how to bake bread'), isFalse);
    });

    test('treats a single word with no dot as a search query', () {
      expect(UrlUtils.looksLikeUrl('flutter'), isFalse);
    });
  });

  group('UrlUtils.normalizeUrl', () {
    test('leaves explicit schemes untouched', () {
      expect(UrlUtils.normalizeUrl('https://example.com'), 'https://example.com');
    });

    test('adds https:// to bare domains', () {
      expect(UrlUtils.normalizeUrl('example.com'), 'https://example.com');
    });
  });

  group('UrlUtils.buildSearchUrl', () {
    test('encodes the query into the template', () {
      final String url = UrlUtils.buildSearchUrl(
        'https://www.google.com/search?q=%s',
        'best programming languages',
      );
      expect(url, 'https://www.google.com/search?q=best%20programming%20languages');
    });
  });

  group('UrlUtils.resolveAddressBarInput', () {
    const String template = 'https://www.google.com/search?q=%s';

    test('resolves a bare domain to a direct URL', () {
      expect(
        UrlUtils.resolveAddressBarInput('example.com', template),
        'https://example.com',
      );
    });

    test('resolves free text to a search URL', () {
      expect(
        UrlUtils.resolveAddressBarInput('best programming languages', template),
        'https://www.google.com/search?q=best%20programming%20languages',
      );
    });
  });

  group('UrlUtils.displayHost', () {
    test('strips scheme, path, and leading www', () {
      expect(UrlUtils.displayHost('https://www.example.com/path?x=1'), 'example.com');
    });
  });

  group('UrlUtils.isValidUrl', () {
    test('accepts well-formed web URLs', () {
      expect(UrlUtils.isValidUrl('https://example.com'), isTrue);
    });

    test('rejects a web scheme with no host', () {
      expect(UrlUtils.isValidUrl('https://'), isFalse);
    });
  });
}
