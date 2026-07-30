import 'package:blindbox_app/features/official_feed/data/firestore_official_feed_loader.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_catalog.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_sources.dart';

/// Loads active official-feed rows for one [sourceId].
typedef OfficialFeedActiveLoader =
    Future<List<OfficialFeedItem>> Function({
      required String sourceId,
      int limit,
    });

/// Read-only official feed — Firestore with in-memory stale fallback.
///
/// **Empty vs failure** (`loadActive`)
/// - Successful empty response replaces and clears that source’s last-good
///   cache (authoritative empty; a later failure cannot resurrect removed posts).
/// - Request failure preserves and returns last-good without modifying the cache.
///
/// **Overlapping loads**
/// - Per-source generation tokens ignore stale completions so an older request
///   cannot overwrite newer last-good / return values used by a newer catalog.
class OfficialFeedRepository {
  OfficialFeedRepository({
    Duration timeout = const Duration(seconds: 12),
    OfficialFeedActiveLoader? loader,
  }) : _timeout = timeout,
       _loader =
           loader ??
           (({required String sourceId, int limit = 12}) =>
               loadFirestoreOfficialFeed(sourceId: sourceId, limit: limit));

  final Duration _timeout;
  final OfficialFeedActiveLoader _loader;

  static final Map<String, List<OfficialFeedItem>> _lastGoodBySource = {};
  static final Map<String, int> _loadGenerationBySource = {};

  /// Active items for POP MART US (legacy helper / tests).
  Future<List<OfficialFeedItem>> loadPopMartUs({int limit = 12}) {
    return loadActive(sourceId: OfficialFeedSources.popmartUs, limit: limit);
  }

  /// Loads every curated Home brand in parallel.
  ///
  /// Per-source failures are isolated inside [loadActive] so one rejected
  /// brand cannot discard successful siblings from [Future.wait].
  Future<OfficialFeedCatalog> loadCuratedHomeCatalog({
    int limitPerSource = 12,
  }) async {
    final entries = await Future.wait(
      OfficialFeedSources.curatedHomeSources.map((sourceId) async {
        final items = await loadActive(
          sourceId: sourceId,
          limit: limitPerSource,
        );
        return MapEntry(sourceId, items);
      }),
    );
    final bySource = {for (final e in entries) e.key: e.value};
    // Fixed curated order — never depend on Map insertion from completion order.
    return OfficialFeedCatalog({
      for (final sourceId in OfficialFeedSources.curatedHomeSources)
        sourceId: List<OfficialFeedItem>.unmodifiable(
          bySource[sourceId] ?? const [],
        ),
    });
  }

  /// Loads active items for one brand.
  ///
  /// Successful empty response replaces and clears that source’s last-good
  /// cache. Request failure preserves and returns last-good without modifying
  /// the cache.
  Future<List<OfficialFeedItem>> loadActive({
    required String sourceId,
    int limit = 12,
  }) async {
    final generation = (_loadGenerationBySource[sourceId] ?? 0) + 1;
    _loadGenerationBySource[sourceId] = generation;

    try {
      final items = await _loader(
        sourceId: sourceId,
        limit: limit,
      ).timeout(_timeout);
      if (_loadGenerationBySource[sourceId] != generation) {
        // Stale response: do not modify the cache; surface current last-good.
        return _lastGoodBySource[sourceId] ?? const [];
      }
      // Success (including empty) replaces that source's last-good cache.
      _lastGoodBySource[sourceId] = List<OfficialFeedItem>.unmodifiable(items);
      return _lastGoodBySource[sourceId]!;
    } catch (_) {
      // Failure: preserve cache unchanged; return last-good when present.
      return _lastGoodBySource[sourceId] ?? const [];
    }
  }

  /// Test helper — clears process-local stale cache / generations.
  static void debugClearLastGoodCache() {
    _lastGoodBySource.clear();
    _loadGenerationBySource.clear();
  }
}
