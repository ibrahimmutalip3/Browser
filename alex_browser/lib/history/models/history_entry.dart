import 'package:equatable/equatable.dart';

/// A single visited-page record. Never created for private tabs — see
/// HistoryRepository.recordVisit, which is simply not called by
/// TabsController when a tab's `isPrivate` flag is true.
class HistoryEntry extends Equatable {
  const HistoryEntry({
    required this.id,
    required this.url,
    required this.title,
    required this.visitedAt,
    this.faviconUrl,
  });

  final String id;
  final String url;
  final String title;
  final DateTime visitedAt;
  final String? faviconUrl;

  factory HistoryEntry.fromMap(Map<String, Object?> map) {
    return HistoryEntry(
      id: map['id']! as String,
      url: map['url']! as String,
      title: map['title']! as String,
      faviconUrl: map['favicon_url'] as String?,
      visitedAt: DateTime.fromMillisecondsSinceEpoch(map['visited_at']! as int),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'url': url,
      'title': title,
      'favicon_url': faviconUrl,
      'visited_at': visitedAt.millisecondsSinceEpoch,
    };
  }

  @override
  List<Object?> get props => <Object?>[id, url, title, visitedAt, faviconUrl];
}
