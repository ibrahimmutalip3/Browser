import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import 'package:alex_browser/core/providers/core_providers.dart';
import 'package:alex_browser/downloads/models/download_item.dart';
import 'package:alex_browser/downloads/services/download_manager_service.dart';

/// Download manager: shows every download (persisted + live) with
/// progress, transfer speed, size, and per-item cancel/retry/delete/open
/// actions.
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  final Map<String, DownloadItem> _items = <String, DownloadItem>{};
  StreamSubscription<DownloadItem>? _subscription;
  bool _loading = true;

  DownloadManagerService get _manager => ref.read(downloadManagerServiceProvider);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final List<DownloadItem> persisted = await _manager.loadPersisted();
    if (!mounted) return;
    setState(() {
      for (final DownloadItem item in persisted) {
        _items[item.id] = item;
      }
      _loading = false;
    });
    _subscription = _manager.updates.listen((DownloadItem item) {
      if (!mounted) return;
      setState(() => _items[item.id] = item);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  List<DownloadItem> get _sorted {
    final List<DownloadItem> list = _items.values.toList()
      ..sort((DownloadItem a, DownloadItem b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _statusLabel(DownloadItem item) {
    switch (item.status) {
      case DownloadStatus.queued:
        return 'Queued';
      case DownloadStatus.inProgress:
        final String received = _formatBytes(item.receivedBytes);
        final String total = item.totalBytes != null ? _formatBytes(item.totalBytes) : '?';
        final String speed = item.bytesPerSecond > 0 ? ' \u2022 ${_formatBytes(item.bytesPerSecond.round())}/s' : '';
        return '$received of $total$speed';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.completed:
        return '${_formatBytes(item.totalBytes ?? item.receivedBytes)} \u2022 Completed';
      case DownloadStatus.failed:
        return 'Failed';
      case DownloadStatus.cancelled:
        return 'Cancelled';
    }
  }

  Future<void> _openFile(DownloadItem item) async {
    final OpenResult result = await OpenFilex.open(item.filePath);
    if (!mounted) return;
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: ${result.message}')),
      );
    }
  }

  Future<void> _clearCompleted() async {
    final List<DownloadItem> completed =
        _items.values.where((DownloadItem i) => i.status == DownloadStatus.completed).toList();
    for (final DownloadItem item in completed) {
      await _manager.deleteDownload(item, deleteFile: false);
      _items.remove(item.id);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final List<DownloadItem> downloads = _sorted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.playlist_remove_rounded),
            tooltip: 'Clear completed',
            onPressed: downloads.any((DownloadItem i) => i.status == DownloadStatus.completed)
                ? _clearCompleted
                : null,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : downloads.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.download_rounded, size: 56, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 12),
                      Text('No downloads yet', style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: downloads.length,
                  itemBuilder: (BuildContext context, int index) {
                    final DownloadItem item = downloads[index];
                    return _DownloadTile(
                      item: item,
                      statusLabel: _statusLabel(item),
                      onOpen: () => _openFile(item),
                      onCancel: () => _manager.cancelDownload(item.id),
                      onRetry: () => _manager.retryDownload(item),
                      onDelete: () async {
                        await _manager.deleteDownload(item);
                        setState(() => _items.remove(item.id));
                      },
                    );
                  },
                ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({
    required this.item,
    required this.statusLabel,
    required this.onOpen,
    required this.onCancel,
    required this.onRetry,
    required this.onDelete,
  });

  final DownloadItem item;
  final String statusLabel;
  final VoidCallback onOpen;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final VoidCallback onDelete;

  IconData get _icon {
    switch (item.status) {
      case DownloadStatus.completed:
        return Icons.insert_drive_file_rounded;
      case DownloadStatus.failed:
        return Icons.error_outline_rounded;
      case DownloadStatus.cancelled:
        return Icons.block_rounded;
      case DownloadStatus.inProgress:
      case DownloadStatus.queued:
      case DownloadStatus.paused:
        return Icons.downloading_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool isActive = item.status == DownloadStatus.inProgress || item.status == DownloadStatus.queued;
    final bool isFailed = item.status == DownloadStatus.failed || item.status == DownloadStatus.cancelled;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.surfaceContainerHighest,
        child: Icon(_icon, color: scheme.onSurfaceVariant),
      ),
      title: Text(item.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(statusLabel, style: Theme.of(context).textTheme.bodySmall),
          if (isActive)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(value: item.progress),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isActive)
            IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Cancel', onPressed: onCancel)
          else if (isFailed)
            IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Retry', onPressed: onRetry)
          else if (item.status == DownloadStatus.completed)
            IconButton(icon: const Icon(Icons.open_in_new_rounded), tooltip: 'Open', onPressed: onOpen),
          IconButton(icon: const Icon(Icons.delete_outline_rounded), tooltip: 'Delete', onPressed: onDelete),
        ],
      ),
      onTap: item.status == DownloadStatus.completed ? onOpen : null,
    );
  }
}
