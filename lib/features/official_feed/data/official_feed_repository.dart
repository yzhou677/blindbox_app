import 'package:blindbox_app/features/official_feed/data/firestore_official_feed_loader.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_sources.dart';

/// Read-only official feed — Firestore with in-memory stale fallback.
class OfficialFeedRepository {
  OfficialFeedRepository({Duration timeout = const Duration(seconds: 12)})
      : _timeout = timeout;

  final Duration _timeout;

  static List<OfficialFeedItem>? _lastGood;

  /// Active items for the default Phase 1 source ([OfficialFeedSources.popmartUs]).
  Future<List<OfficialFeedItem>> loadPopMartUs({int limit = 12}) {
    return loadActive(sourceId: OfficialFeedSources.popmartUs, limit: limit);
  }

  Future<List<OfficialFeedItem>> loadActive({
    required String sourceId,
    int limit = 12,
  }) async {
    try {
      final items = await loadFirestoreOfficialFeed(
        sourceId: sourceId,
        limit: limit,
      ).timeout(_timeout);
      if (items.isNotEmpty) {
        _lastGood = List<OfficialFeedItem>.unmodifiable(items);
      }
      return items;
    } catch (_) {
      return _lastGood ?? const [];
    }
  }
}
