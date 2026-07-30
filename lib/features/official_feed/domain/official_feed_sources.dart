/// Stable source ids for Firestore `official_feed_items`.
///
/// These are **feed** keys (`popmart_us`), not Market taxonomy ids (`pop_mart`).
abstract final class OfficialFeedSources {
  OfficialFeedSources._();

  static const String popmartUs = 'popmart_us';
  static const String tntspaceUs = 'tntspace_us';
  static const String toptoyUs = 'toptoy_us';
  static const String sonnyangelUs = 'sonnyangel_us';

  /// Home Official feeds brands, left-to-right chip order.
  static const List<String> curatedHomeSources = [
    popmartUs,
    tntspaceUs,
    toptoyUs,
    sonnyangelUs,
  ];

  /// Chip / section label for a curated [sourceId].
  static String displayLabel(String sourceId) {
    return switch (sourceId) {
      popmartUs => 'POP MART',
      tntspaceUs => 'TNT SPACE',
      toptoyUs => 'TOP TOY',
      sonnyangelUs => 'Sonny Angel',
      _ => sourceId,
    };
  }

  /// Whether Home should show brand filter chips.
  ///
  /// Visible when **two or more** sources currently have displayable content.
  /// Empty / unavailable brands are never chip targets.
  static bool shouldShowBrandFilters(Iterable<String> availableSourceIds) {
    return availableSourceIds.length >= 2;
  }

  /// Ordered available sources in configured chip order.
  static List<String> orderedAvailableSources(
    Iterable<String> availableSourceIds,
  ) {
    final available = availableSourceIds.toSet();
    return [
      for (final id in curatedHomeSources)
        if (available.contains(id)) id,
    ];
  }

  /// Picks which source to show, or `null` when none are available.
  ///
  /// Preserves [preferred] while it remains available; otherwise the first
  /// available source in [curatedHomeSources] order. Never selects POP MART
  /// (or any brand) when it has no displayable content.
  static String? resolveSelection({
    required Iterable<String> availableSourceIds,
    String? preferred,
  }) {
    final ordered = orderedAvailableSources(availableSourceIds);
    if (ordered.isEmpty) return null;
    if (preferred != null && ordered.contains(preferred)) {
      return preferred;
    }
    return ordered.first;
  }
}
