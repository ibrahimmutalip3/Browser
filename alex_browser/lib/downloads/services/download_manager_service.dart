import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:alex_browser/browser/models/download_request.dart';
import 'package:alex_browser/downloads/models/download_item.dart';
import 'package:alex_browser/downloads/repositories/downloads_repository.dart';

/// Performs real, streamed file downloads triggered by the browser engine
/// (see BrowserEngine.downloadRequests) using the platform's Downloads-like
/// directory. Tracks per-download progress and transfer speed, and
/// supports cancel/retry.
///
/// Android and iOS have different notions of a "Downloads" folder:
/// - Android: files go to the app's external files directory under a
///   "Download" subfolder (scoped storage compliant, no storage
///   permission needed on modern Android) and are also indexed via
///   MediaStore-style visibility is not attempted here since that needs
///   platform channel code; instead, files are opened directly with
///   open_filex, which resolves a content:// URI as needed.
/// - iOS: apps cannot write to a shared Downloads folder; files are saved
///   inside the app's own Documents directory (visible via the Files app
///   under "On My iPhone > Alex Browser" since the app enables
///   `UIFileSharingEnabled`/`LSSupportsOpeningDocumentsInPlace`).
class DownloadManagerService {
  DownloadManagerService({DownloadsRepository? repository, http.Client? httpClient})
      : _repository = repository ?? DownloadsRepository(),
        _client = httpClient ?? http.Client(),
        _uuid = const Uuid();

  final DownloadsRepository _repository;
  final http.Client _client;
  final Uuid _uuid;

  final StreamController<DownloadItem> _updates = StreamController<DownloadItem>.broadcast();
  final Map<String, StreamSubscription<List<int>>> _activeStreams = <String, StreamSubscription<List<int>>>{};
  final Map<String, IOSink> _activeSinks = <String, IOSink>{};
  final Map<String, DownloadItem> _items = <String, DownloadItem>{};

  /// Emits an updated [DownloadItem] every time progress changes, or the
  /// status transitions (queued -> inProgress -> completed/failed/cancelled).
  Stream<DownloadItem> get updates => _updates.stream;

  Future<Directory> _downloadsDirectory() async {
    if (Platform.isAndroid) {
      final Directory? external = await getExternalStorageDirectory();
      final Directory base = external ?? await getApplicationDocumentsDirectory();
      final Directory downloadDir = Directory(p.join(base.path, 'Download'));
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir;
    }
    // iOS: Documents directory, exposed to the Files app via Info.plist
    // entitlements configured in ios/Runner/Info.plist.
    return getApplicationDocumentsDirectory();
  }

  String _uniqueFileName(Directory dir, String suggested) {
    final String safe = suggested.trim().isEmpty ? 'download' : suggested.trim();
    final String ext = p.extension(safe);
    final String stem = p.basenameWithoutExtension(safe);
    String candidate = safe;
    int counter = 1;
    while (File(p.join(dir.path, candidate)).existsSync()) {
      candidate = '$stem ($counter)$ext';
      counter++;
    }
    return candidate;
  }

  /// Starts downloading [request], persisting metadata immediately (status
  /// = queued) and then streaming bytes to disk while updating progress.
  Future<DownloadItem> startDownload(EngineDownloadRequest request) async {
    final Directory dir = await _downloadsDirectory();
    final String fileName = _uniqueFileName(dir, request.suggestedFileName);
    final String filePath = p.join(dir.path, fileName);

    DownloadItem item = DownloadItem(
      id: _uuid.v4(),
      url: request.url,
      fileName: fileName,
      filePath: filePath,
      status: DownloadStatus.queued,
      createdAt: DateTime.now(),
      mimeType: request.mimeType,
      totalBytes: request.contentLength,
    );
    _items[item.id] = item;
    await _repository.upsert(item);
    _updates.add(item);

    unawaited(_run(item, request.userAgent));
    return item;
  }

  Future<void> _run(DownloadItem initial, String? userAgent) async {
    final String id = initial.id;
    DownloadItem item = initial.copyWith(status: DownloadStatus.inProgress);
    _items[id] = item;
    await _repository.upsert(item);
    _updates.add(item);

    IOSink? sink;
    try {
      final http.Request req = http.Request('GET', Uri.parse(item.url));
      if (userAgent != null) {
        req.headers['User-Agent'] = userAgent;
      }
      final http.StreamedResponse response = await _client.send(req);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      final int? contentLength = response.contentLength ?? item.totalBytes;
      final File file = File(item.filePath);
      sink = file.openWrite();
      _activeSinks[id] = sink;

      int received = 0;
      final DateTime startTime = DateTime.now();
      int lastEmitBytes = 0;
      DateTime lastEmitTime = startTime;

      final Completer<void> done = Completer<void>();
      final StreamSubscription<List<int>> sub = response.stream.listen(
        (List<int> chunk) {
          sink!.add(chunk);
          received += chunk.length;

          final DateTime now = DateTime.now();
          final double elapsed = now.difference(lastEmitTime).inMilliseconds / 1000.0;
          // Throttle UI updates to roughly 4x/second to avoid excessive
          // rebuilds while still feeling live.
          if (elapsed >= 0.25) {
            final double bytesPerSecond = elapsed > 0 ? (received - lastEmitBytes) / elapsed : 0;
            lastEmitBytes = received;
            lastEmitTime = now;
            item = item.copyWith(
              receivedBytes: received,
              totalBytes: contentLength,
              bytesPerSecond: bytesPerSecond,
            );
            _items[id] = item;
            _updates.add(item);
          }
        },
        onDone: () => done.complete(),
        onError: done.completeError,
        cancelOnError: true,
      );
      _activeStreams[id] = sub;

      await done.future;
      await sink.flush();
      await sink.close();
      _activeSinks.remove(id);
      _activeStreams.remove(id);

      item = item.copyWith(
        status: DownloadStatus.completed,
        receivedBytes: received,
        totalBytes: contentLength ?? received,
        completedAt: DateTime.now(),
        bytesPerSecond: 0,
      );
      _items[id] = item;
      await _repository.upsert(item);
      _updates.add(item);
    } catch (error) {
      await sink?.close();
      _activeSinks.remove(id);
      _activeStreams.remove(id);

      // A cancellation surfaces here too (stream closed mid-read); only
      // overwrite status to failed if it wasn't already marked cancelled
      // by cancelDownload().
      final DownloadItem? current = _items[id];
      if (current?.status != DownloadStatus.cancelled) {
        item = item.copyWith(status: DownloadStatus.failed, bytesPerSecond: 0);
        _items[id] = item;
        await _repository.upsert(item);
        _updates.add(item);
      }
    }
  }

  Future<void> cancelDownload(String id) async {
    final DownloadItem? item = _items[id];
    if (item == null) return;
    await _activeStreams[id]?.cancel();
    await _activeSinks[id]?.close();
    _activeStreams.remove(id);
    _activeSinks.remove(id);

    final DownloadItem updated = item.copyWith(status: DownloadStatus.cancelled, bytesPerSecond: 0);
    _items[id] = updated;
    await _repository.upsert(updated);
    _updates.add(updated);

    try {
      final File file = File(item.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup only.
    }
  }

  Future<void> retryDownload(DownloadItem item) async {
    try {
      final File file = File(item.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore; startDownload below will overwrite/create as needed.
    }
    unawaited(
      startDownload(
        EngineDownloadRequest(
          url: item.url,
          suggestedFileName: item.fileName,
          mimeType: item.mimeType,
          contentLength: item.totalBytes,
        ),
      ),
    );
    await _repository.delete(item.id);
  }

  Future<void> deleteDownload(DownloadItem item, {bool deleteFile = true}) async {
    if (deleteFile) {
      try {
        final File file = File(item.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Best-effort.
      }
    }
    await _repository.delete(item.id);
  }

  Future<List<DownloadItem>> loadPersisted() => _repository.getAll();

  void dispose() {
    for (final StreamSubscription<List<int>> sub in _activeStreams.values) {
      sub.cancel();
    }
    for (final IOSink sink in _activeSinks.values) {
      sink.close();
    }
    _updates.close();
    _client.close();
  }
}
