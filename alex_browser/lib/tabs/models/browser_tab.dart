import 'package:equatable/equatable.dart';

import 'package:alex_browser/browser/models/page_load_state.dart';

/// A single browser tab: its identity, session-restorable fields, and the
/// live [PageLoadState] reported by its [BrowserEngine] instance.
///
/// The heavyweight [BrowserEngine] itself is NOT stored here — it lives in
/// [TabsController]'s internal engine map, keyed by tab id — so that this
/// model stays a cheap, immutable value object safe to rebuild on every
/// Riverpod state change.
class BrowserTab extends Equatable {
  const BrowserTab({
    required this.id,
    required this.isPrivate,
    required this.createdAt,
    this.pageState = PageLoadState.initial,
  });

  final String id;
  final bool isPrivate;
  final DateTime createdAt;
  final PageLoadState pageState;

  String get title {
    if (pageState.title.isNotEmpty) return pageState.title;
    if (pageState.url.isNotEmpty) return pageState.url;
    return 'New Tab';
  }

  String get url => pageState.url;
  String? get faviconUrl => pageState.faviconUrl;
  bool get isLoading => pageState.isLoading;

  BrowserTab copyWith({PageLoadState? pageState}) {
    return BrowserTab(
      id: id,
      isPrivate: isPrivate,
      createdAt: createdAt,
      pageState: pageState ?? this.pageState,
    );
  }

  /// Row for the `tabs_session` table (session restoration). Private tabs
  /// are never persisted here — see TabsController, which skips saving
  /// private tabs entirely — but the mapping is defined here for symmetry
  /// with the other models.
  Map<String, Object?> toMap({required int sortOrder, required bool isActive}) {
    return <String, Object?>{
      'id': id,
      'url': pageState.url,
      'title': pageState.title,
      'favicon_url': pageState.faviconUrl,
      'is_private': isPrivate ? 1 : 0,
      'sort_order': sortOrder,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory BrowserTab.fromMap(Map<String, Object?> map) {
    return BrowserTab(
      id: map['id']! as String,
      isPrivate: (map['is_private'] as int? ?? 0) == 1,
      createdAt: DateTime.now(),
      pageState: PageLoadState.initial.copyWith(
        url: map['url'] as String? ?? '',
        title: map['title'] as String? ?? '',
        faviconUrl: map['favicon_url'] as String?,
      ),
    );
  }

  @override
  List<Object?> get props => <Object?>[id, isPrivate, createdAt, pageState];
}
