import 'package:equatable/equatable.dart';

class BookmarkFolder extends Equatable {
  const BookmarkFolder({
    required this.id,
    required this.name,
    required this.createdAt,
    this.parentId,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String? parentId;
  final DateTime createdAt;
  final int sortOrder;

  factory BookmarkFolder.fromMap(Map<String, Object?> map) {
    return BookmarkFolder(
      id: map['id']! as String,
      name: map['name']! as String,
      parentId: map['parent_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'parent_id': parentId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'sort_order': sortOrder,
    };
  }

  BookmarkFolder copyWith({String? name, String? parentId, int? sortOrder}) {
    return BookmarkFolder(
      id: id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, name, parentId, createdAt, sortOrder];
}

class Bookmark extends Equatable {
  const Bookmark({
    required this.id,
    required this.url,
    required this.title,
    required this.createdAt,
    this.faviconUrl,
    this.folderId,
    this.sortOrder = 0,
  });

  final String id;
  final String url;
  final String title;
  final String? faviconUrl;
  final String? folderId;
  final DateTime createdAt;
  final int sortOrder;

  factory Bookmark.fromMap(Map<String, Object?> map) {
    return Bookmark(
      id: map['id']! as String,
      url: map['url']! as String,
      title: map['title']! as String,
      faviconUrl: map['favicon_url'] as String?,
      folderId: map['folder_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'url': url,
      'title': title,
      'favicon_url': faviconUrl,
      'folder_id': folderId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'sort_order': sortOrder,
    };
  }

  Bookmark copyWith({String? title, String? folderId, bool clearFolder = false, int? sortOrder}) {
    return Bookmark(
      id: id,
      url: url,
      title: title ?? this.title,
      faviconUrl: faviconUrl,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      createdAt: createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props => <Object?>[id, url, title, faviconUrl, folderId, createdAt, sortOrder];
}
