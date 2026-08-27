import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:alex_browser/core/providers/core_providers.dart';
import 'package:alex_browser/core/utils/url_utils.dart';
import 'package:alex_browser/history/models/history_entry.dart';
import 'package:alex_browser/history/repositories/history_repository.dart';
import 'package:alex_browser/tabs/controllers/tabs_controller.dart';

/// Browsing history: searchable, grouped by day, with per-entry delete and
/// a full "Clear browsing history" action. Tapping an entry navigates the
/// active tab to that URL and closes this screen, matching how Chrome's
/// history list behaves.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<HistoryEntry> _entries = <HistoryEntry>[];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final HistoryRepository repo = ref.read(historyRepositoryProvider);
    final List<HistoryEntry> entries =
        _query.isEmpty ? await repo.getAll() : await repo.search(_query);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _deleteEntry(HistoryEntry entry) async {
    await ref.read(historyRepositoryProvider).deleteEntry(entry.id);
    await _load();
  }

  Future<void> _clearAll() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Clear browsing history?'),
        content: const Text('This will permanently delete your entire browsing history.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(historyRepositoryProvider).clearAll();
      await _load();
    }
  }

  Map<String, List<HistoryEntry>> _groupedByDay() {
    final Map<String, List<HistoryEntry>> grouped = <String, List<HistoryEntry>>{};
    final DateFormat headerFormat = DateFormat('EEEE, MMMM d');
    final DateTime now = DateTime.now();
    for (final HistoryEntry entry in _entries) {
      final DateTime day = DateTime(entry.visitedAt.year, entry.visitedAt.month, entry.visitedAt.day);
      final DateTime today = DateTime(now.year, now.month, now.day);
      final DateTime yesterday = today.subtract(const Duration(days: 1));
      final String label = day == today
          ? 'Today'
          : day == yesterday
              ? 'Yesterday'
              : headerFormat.format(day);
      grouped.putIfAbsent(label, () => <HistoryEntry>[]).add(entry);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<HistoryEntry>> grouped = _groupedByDay();

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear browsing history',
            onPressed: _entries.isEmpty ? null : _clearAll,
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
                hintText: 'Search history',
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
                : _entries.isEmpty
                    ? Center(
                        child: Text(
                          _query.isEmpty ? 'No browsing history yet' : 'No results',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : ListView(
                        children: grouped.entries.map((MapEntry<String, List<HistoryEntry>> group) {
                          return _HistorySection(
                            label: group.key,
                            entries: group.value,
                            onTap: (HistoryEntry entry) {
                              ref
                                  .read(tabsControllerProvider.notifier)
                                  .navigateActiveTab(entry.url);
                              Navigator.of(context).pop();
                            },
                            onDelete: _deleteEntry,
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.label,
    required this.entries,
    required this.onTap,
    required this.onDelete,
  });

  final String label;
  final List<HistoryEntry> entries;
  final ValueChanged<HistoryEntry> onTap;
  final ValueChanged<HistoryEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final DateFormat timeFormat = DateFormat('HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        ...entries.map(
          (HistoryEntry entry) => Dismissible(
            key: ValueKey<String>(entry.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Theme.of(context).colorScheme.errorContainer,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Icon(Icons.delete_rounded, color: Theme.of(context).colorScheme.onErrorContainer),
            ),
            onDismissed: (_) => onDelete(entry),
            child: ListTile(
              leading: _EntryFavicon(url: entry.faviconUrl),
              title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                UrlUtils.displayHost(entry.url),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                timeFormat.format(entry.visitedAt),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              onTap: () => onTap(entry),
            ),
          ),
        ),
      ],
    );
  }
}

class _EntryFavicon extends StatelessWidget {
  const _EntryFavicon({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const CircleAvatar(radius: 14, child: Icon(Icons.public_rounded, size: 16));
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
          errorBuilder: (_, __, ___) => const Icon(Icons.public_rounded, size: 16),
        ),
      ),
    );
  }
}
