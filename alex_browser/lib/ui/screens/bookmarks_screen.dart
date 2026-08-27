import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alex_browser/bookmarks/models/bookmark.dart';
import 'package:alex_browser/bookmarks/repositories/bookmarks_repository.dart';
import 'package:alex_browser/core/providers/core_providers.dart';
import 'package:alex_browser/core/utils/url_utils.dart';
import 'package:alex_browser/tabs/controllers/tabs_controller.dart';

/// Bookmarks manager: browse folders, search across all bookmarks, add a
/// new folder, rename/delete/move individual bookmarks. Root view shows
/// folders first, then unfiled bookmarks, matching Chrome/Safari's
/// bookmarks-manager layout.
class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _currentFolderId;
  String _currentFolderName = 'Bookmarks';
  List<BookmarkFolder> _folders = <BookmarkFolder>[];
  List<Bookmark> _bookmarks = <Bookmark>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  BookmarksRepository get _repo => ref.read(bookmarksRepositoryProvider);

  Future<void> _load() async {
    setState(() => _loading = true);
    if (_query.isNotEmpty) {
      final List<Bookmark> results = await _repo.search(_query);
      if (!mounted) return;
      setState(() {
        _bookmarks = results;
        _folders = <BookmarkFolder>[];
        _loading = false;
      });
      return;
    }
    final List<BookmarkFolder> folders = await _repo.getFolders(parentId: _currentFolderId);
    final List<Bookmark> bookmarks = await _repo.getAll(folderId: _currentFolderId);
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _bookmarks = bookmarks;
      _loading = false;
    });
  }

  void _openFolder(BookmarkFolder folder) {
    setState(() {
      _currentFolderId = folder.id;
      _currentFolderName = folder.name;
    });
    _load();
  }

  void _goToRoot() {
    setState(() {
      _currentFolderId = null;
      _currentFolderName = 'Bookmarks';
    });
    _load();
  }

  Future<void> _addFolder() async {
    final String? name = await _promptForText(context, title: 'New folder', hint: 'Folder name');
    if (name == null || name.trim().isEmpty) return;
    await _repo.addFolder(name.trim(), parentId: _currentFolderId);
    await _load();
  }

  Future<void> _rename(Bookmark bookmark) async {
    final String? name = await _promptForText(
      context,
      title: 'Rename bookmark',
      hint: 'Title',
      initial: bookmark.title,
    );
    if (name == null || name.trim().isEmpty) return;
    await _repo.rename(bookmark.id, name.trim());
    await _load();
  }

  Future<void> _delete(Bookmark bookmark) async {
    await _repo.remove(bookmark.id);
    await _load();
  }

  Future<void> _deleteFolder(BookmarkFolder folder) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Delete "${folder.name}"?'),
        content: const Text('Bookmarks inside this folder will be moved out of it.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _repo.removeFolder(folder.id);
      await _load();
    }
  }

  Future<String?> _promptForText(
    BuildContext context, {
    required String title,
    required String hint,
    String initial = '',
  }) {
    final TextEditingController controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool inFolder = _currentFolderId != null;
    return Scaffold(
      appBar: AppBar(
        leading: inFolder
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _goToRoot)
            : null,
        title: Text(_currentFolderName),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.create_new_folder_rounded),
            tooltip: 'New folder',
            onPressed: _addFolder,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search bookmarks',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                          _load();
                        },
                      )
                    : null,
              ),
              onChanged: (String value) {
                setState(() => _query = value);
                _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_folders.isEmpty && _bookmarks.isEmpty)
                    ? Center(
                        child: Text(
                          _query.isEmpty ? 'No bookmarks yet' : 'No results',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : ListView(
                        children: <Widget>[
                          ..._folders.map(
                            (BookmarkFolder folder) => ListTile(
                              leading: const Icon(Icons.folder_rounded),
                              title: Text(folder.name),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () => _deleteFolder(folder),
                              ),
                              onTap: () => _openFolder(folder),
                            ),
                          ),
                          if (_folders.isNotEmpty && _bookmarks.isNotEmpty) const Divider(height: 1),
                          ..._bookmarks.map(
                            (Bookmark bookmark) => Dismissible(
                              key: ValueKey<String>(bookmark.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Theme.of(context).colorScheme.errorContainer,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Icon(
                                  Icons.delete_rounded,
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                ),
                              ),
                              onDismissed: (_) => _delete(bookmark),
                              child: ListTile(
                                leading: _BookmarkFavicon(url: bookmark.faviconUrl),
                                title: Text(bookmark.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                  UrlUtils.displayHost(bookmark.url),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (String action) {
                                    if (action == 'rename') _rename(bookmark);
                                    if (action == 'delete') _delete(bookmark);
                                  },
                                  itemBuilder: (BuildContext ctx) => const <PopupMenuEntry<String>>[
                                    PopupMenuItem<String>(value: 'rename', child: Text('Rename')),
                                    PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                                  ],
                                ),
                                onTap: () {
                                  ref
                                      .read(tabsControllerProvider.notifier)
                                      .navigateActiveTab(bookmark.url);
                                  Navigator.of(context).pop();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkFavicon extends StatelessWidget {
  const _BookmarkFavicon({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const CircleAvatar(radius: 14, child: Icon(Icons.bookmark_rounded, size: 16));
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          url!,
          width: 22,
          height: 22,
          errorBuilder: (_, __, ___) => const Icon(Icons.bookmark_rounded, size: 16),
        ),
      ),
    );
  }
}
