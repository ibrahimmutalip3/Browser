import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alex_browser/bookmarks/models/bookmark.dart';
import 'package:alex_browser/core/providers/core_providers.dart';

/// The overflow menu shown when tapping the "⋮" button in the address bar:
/// bookmark the current page, open History/Bookmarks/Downloads/Settings,
/// and start new normal/private tabs.
class BrowserMenuSheet extends ConsumerStatefulWidget {
  const BrowserMenuSheet({
    super.key,
    required this.currentUrl,
    required this.currentTitle,
    required this.onHistory,
    required this.onBookmarks,
    required this.onDownloads,
    required this.onSettings,
    required this.onNewTab,
    required this.onNewPrivateTab,
  });

  final String currentUrl;
  final String currentTitle;
  final VoidCallback onHistory;
  final VoidCallback onBookmarks;
  final VoidCallback onDownloads;
  final VoidCallback onSettings;
  final VoidCallback onNewTab;
  final VoidCallback onNewPrivateTab;

  @override
  ConsumerState<BrowserMenuSheet> createState() => _BrowserMenuSheetState();
}

class _BrowserMenuSheetState extends ConsumerState<BrowserMenuSheet> {
  bool _checking = true;
  bool _bookmarked = false;
  Bookmark? _existing;

  @override
  void initState() {
    super.initState();
    _checkBookmarked();
  }

  Future<void> _checkBookmarked() async {
    if (widget.currentUrl.isEmpty) {
      setState(() => _checking = false);
      return;
    }
    final Bookmark? found = await ref.read(bookmarksRepositoryProvider).findByUrl(widget.currentUrl);
    if (!mounted) return;
    setState(() {
      _existing = found;
      _bookmarked = found != null;
      _checking = false;
    });
  }

  Future<void> _toggleBookmark() async {
    if (widget.currentUrl.isEmpty) return;
    if (_bookmarked && _existing != null) {
      await ref.read(bookmarksRepositoryProvider).remove(_existing!.id);
      if (!mounted) return;
      setState(() {
        _bookmarked = false;
        _existing = null;
      });
    } else {
      final Bookmark created = await ref.read(bookmarksRepositoryProvider).add(
            url: widget.currentUrl,
            title: widget.currentTitle,
          );
      if (!mounted) return;
      setState(() {
        _bookmarked = true;
        _existing = created;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(_bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
              title: Text(_bookmarked ? 'Remove bookmark' : 'Add bookmark'),
              enabled: !_checking && widget.currentUrl.isNotEmpty,
              onTap: _toggleBookmark,
            ),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('New tab'),
              onTap: widget.onNewTab,
            ),
            ListTile(
              leading: const Icon(Icons.security_rounded),
              title: const Text('New private tab'),
              onTap: widget.onNewPrivateTab,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('History'),
              onTap: widget.onHistory,
            ),
            ListTile(
              leading: const Icon(Icons.bookmarks_rounded),
              title: const Text('Bookmarks'),
              onTap: widget.onBookmarks,
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Downloads'),
              onTap: widget.onDownloads,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_rounded),
              title: const Text('Settings'),
              onTap: widget.onSettings,
            ),
          ],
        ),
      ),
    );
  }
}
