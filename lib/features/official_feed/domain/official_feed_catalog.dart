import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_sources.dart';

/// Per-brand official feed lists loaded for Home.
///
/// A source is **available** when its list is non-empty (active items from a
/// successful load, or non-empty last-good after a failed request). Empty
/// successful loads and failure-with-no-cache leave an empty list and are
/// unavailable.
class OfficialFeedCatalog {
  const OfficialFeedCatalog(this.bySource);

  final Map<String, List<OfficialFeedItem>> bySource;

  static const empty = OfficialFeedCatalog({});

  /// Available source ids in configured order (POP MART → TNT → TOP TOY).
  List<String> get availableSources =>
      OfficialFeedSources.orderedAvailableSources({
        for (final e in bySource.entries)
          if (e.value.isNotEmpty) e.key,
      });

  /// Unordered view of [availableSources] for set-style checks.
  Set<String> get availableSourceIds => availableSources.toSet();

  bool get hasAnyItems => availableSources.isNotEmpty;

  bool get showBrandFilters =>
      OfficialFeedSources.shouldShowBrandFilters(availableSources);

  List<OfficialFeedItem> itemsFor(String sourceId) =>
      bySource[sourceId] ?? const [];
}
