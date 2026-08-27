import 'package:flutter/material.dart';

import 'package:alex_browser/browser/models/page_load_state.dart';
import 'package:alex_browser/core/utils/url_utils.dart';

/// A full-screen, in-engine-view error page shown when navigation fails.
/// This is not rendered by the WebView (there is no HTML for it to load
/// after a network error) — it is a native Flutter overlay drawn on top
/// of the tab's content area, matching how Chrome/Safari present their
/// own native error pages rather than degraded web content.
class ErrorPage extends StatelessWidget {
  const ErrorPage({
    super.key,
    required this.state,
    required this.onReload,
    required this.onGoHome,
  });

  final PageLoadState state;
  final VoidCallback onReload;
  final VoidCallback onGoHome;

  _ErrorContent _contentFor(PageErrorType type) {
    switch (type) {
      case PageErrorType.noInternet:
        return const _ErrorContent(
          icon: Icons.wifi_off_rounded,
          title: 'No internet connection',
          message: 'Check your Wi-Fi or mobile data connection and try again.',
        );
      case PageErrorType.dnsFailure:
        return const _ErrorContent(
          icon: Icons.dns_rounded,
          title: 'Site can\u2019t be found',
          message: 'Alex Browser couldn\u2019t find the server for this address. '
              'Check the address for typos.',
        );
      case PageErrorType.timeout:
        return const _ErrorContent(
          icon: Icons.hourglass_bottom_rounded,
          title: 'Connection timed out',
          message: 'The site took too long to respond. It may be temporarily '
              'down or too busy.',
        );
      case PageErrorType.connectionRefused:
        return const _ErrorContent(
          icon: Icons.cloud_off_rounded,
          title: 'Unable to load page',
          message: 'The connection to the server was refused. Check your '
              'internet connection and try again.',
        );
      case PageErrorType.sslError:
        return const _ErrorContent(
          icon: Icons.lock_outline_rounded,
          title: 'Connection isn\u2019t private',
          message: 'This site\u2019s security certificate is not trusted. For '
              'your safety, Alex Browser did not load this page.',
        );
      case PageErrorType.invalidUrl:
        return const _ErrorContent(
          icon: Icons.link_off_rounded,
          title: 'Invalid address',
          message: 'That doesn\u2019t look like a valid web address.',
        );
      case PageErrorType.httpError:
        return _ErrorContent(
          icon: Icons.error_outline_rounded,
          title: state.httpStatusCode != null ? 'HTTP ${state.httpStatusCode} error' : 'Page error',
          message: state.errorDescription ?? 'The server returned an error for this page.',
        );
      case PageErrorType.unknown:
      case PageErrorType.none:
        return _ErrorContent(
          icon: Icons.error_outline_rounded,
          title: 'Unable to load page',
          message: state.errorDescription ?? 'Something went wrong while loading this page.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final _ErrorContent content = _contentFor(state.errorType);

    return Container(
      color: scheme.surface,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(content.icon, size: 72, color: scheme.onSurfaceVariant),
          const SizedBox(height: 24),
          Text(
            content.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            content.message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (state.url.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              UrlUtils.displayHost(state.url),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 28),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: onGoHome,
                icon: const Icon(Icons.home_rounded, size: 18),
                label: const Text('Home'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onReload,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reload'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorContent {
  const _ErrorContent({required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;
}
