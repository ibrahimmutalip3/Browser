import 'package:equatable/equatable.dart';

enum DownloadStatus { queued, inProgress, paused, completed, failed, cancelled }

class DownloadItem extends Equatable {
  const DownloadItem({
    required this.id,
    required this.url,
    required this.fileName,
    required this.filePath,
    required this.status,
    required this.createdAt,
    this.mimeType,
    this.totalBytes,
    this.receivedBytes = 0,
    this.completedAt,
    this.bytesPerSecond = 0,
  });

  final String id;
  final String url;
  final String fileName;
  final String filePath;
  final String? mimeType;
  final int? totalBytes;
  final int receivedBytes;
  final DownloadStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;

  /// Transient, not persisted — used only for the live speed readout
  /// while a download is actively in progress.
  final double bytesPerSecond;

  double? get progress {
    final int? total = totalBytes;
    if (total == null || total <= 0) return null;
    return (receivedBytes / total).clamp(0.0, 1.0);
  }

  factory DownloadItem.fromMap(Map<String, Object?> map) {
    return DownloadItem(
      id: map['id']! as String,
      url: map['url']! as String,
      fileName: map['file_name']! as String,
      filePath: map['file_path']! as String,
      mimeType: map['mime_type'] as String?,
      totalBytes: map['total_bytes'] as int?,
      receivedBytes: (map['received_bytes'] as int?) ?? 0,
      status: DownloadStatus.values.firstWhere(
        (DownloadStatus s) => s.name == map['status'],
        orElse: () => DownloadStatus.failed,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at']! as int)
          : null,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'url': url,
      'file_name': fileName,
      'file_path': filePath,
      'mime_type': mimeType,
      'total_bytes': totalBytes,
      'received_bytes': receivedBytes,
      'status': status.name,
      'created_at': createdAt.millisecondsSinceEpoch,
      'completed_at': completedAt?.millisecondsSinceEpoch,
    };
  }

  DownloadItem copyWith({
    int? totalBytes,
    int? receivedBytes,
    DownloadStatus? status,
    DateTime? completedAt,
    double? bytesPerSecond,
  }) {
    return DownloadItem(
      id: id,
      url: url,
      fileName: fileName,
      filePath: filePath,
      mimeType: mimeType,
      totalBytes: totalBytes ?? this.totalBytes,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        url,
        fileName,
        filePath,
        mimeType,
        totalBytes,
        receivedBytes,
        status,
        createdAt,
        completedAt,
      ];
}
