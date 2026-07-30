/// Canonical user-facing labels for the Collection module.
///
/// One name per concept — summary, insights, shelf cards, and sheets
/// should import from here instead of inventing parallel wording.
abstract final class CollectionVocabulary {
  CollectionVocabulary._();

  /// Owned figure count — prefer in aggregate / summary surfaces.
  static const ownedFigures = 'Owned Figures';

  /// Wishlisted figure count — Collection Summary only (forward-looking).
  static const wishlistedFigures = 'Wishlisted Figures';

  /// Short inline chip label (e.g. progress voice).
  static const figures = 'Figures';

  /// Short inline chip label (e.g. progress voice).
  static const wishlist = 'Wishlist';

  static const completedSeries = 'Completed Series';
  static const masterComplete = 'Master Complete';

  /// Shelf Progress — primary progression row (always shown).
  static const regularProgress = 'Regular Progress';

  /// Shelf Progress — secondary row; only after first Master Complete series.
  static const masterCompletion = 'Master Completion';

  /// Secret figures the collector owns — Insights at-a-glance.
  static const secretsCollected = 'Secrets Collected';

  static const secretFigure = 'Secret Figure';
  static const secretFigures = 'Secret Figures';
  static const regularFigures = 'Regular Figures';
  static const collected = 'Collected';
  static const series = 'Series';

  /// Compact series card badge when all regular figures are owned.
  static const seriesCompleteBadge = '✓ Complete';

  /// Collection advanced filters entry / sheet title.
  static const filters = 'Filters';

  static const filterSectionProgress = 'Progress';
  static const filterSectionCollectionAttributes = 'Collection Attributes';
  static const filterSectionMetadata = 'Metadata';

  /// @Deprecated — prefer [filterSectionCollectionAttributes].
  static const filterSectionCollectionStatus = 'Collection Status';

  static const progressInProgressFilter = 'In Progress';
  static const progressCompletedFilter = 'Completed';
  static const progressMasterCompleteFilter = 'Master Complete';

  /// Collection shelf filter — series with at least one duplicate copy.
  static const hasDuplicatesFilter = 'Has Duplicates';
  static const hasWishlistItemsFilter = 'Has Wishlist Items';
  static const secretOwnedFilter = 'Secret Owned';
  static const secretMissingFilter = 'Secret Missing';
  static const customSeriesFilter = 'Custom Series';

  static const filterBrand = 'Brand';
  static const filterIp = 'IP';
  static const filterSearchBrandsHint = 'Search brands';
  static const filterSearchIpsHint = 'Search IPs';

  /// Filters sheet primary action base (legacy; prefer [showFilterSeriesCount]).
  static const showFilterResults = 'Show results';

  /// Filters sheet primary action — series count after draft filters + search.
  static String showFilterSeriesCount(int count) => 'Show $count Series';

  /// Filters sheet — Sort section (separate from filter chips).
  static const filterSectionSortBy = 'Sort by';

  /// Collapsed Brand summary when nothing is selected.
  static const filterAllBrandsSummary = 'All brands';

  /// Collapsed IP summary when nothing is selected.
  static const filterAllIpsSummary = 'All IPs';

  /// Collapsed Brand/IP summary for multiple selections.
  static String filterSelectedCountSummary(int count) => '$count selected';

  /// Filters sheet reset action.
  static const clearAllFilters = 'Clear all';

  static const filteredEmptyTitle = 'No series match these filters';
  static const filteredEmptyAction = 'Clear filters';
  static const layoutMenuTitle = 'Layout';

  /// Layout sheet — optional Series Card metadata.
  static const cardContentSectionTitle = 'Card Content';
  static const cardContentSectionSubtitle = 'Choose up to 2 details to show';

  static String cardContentSelectionCount(int selected, int max) =>
      '$selected of $max selected';

  /// Compact figure-card quantity badge prefix (e.g. `×2`).
  static String ownedQuantityBadge(int quantity) => '×$quantity';

  /// Toolbar label with optional active-count suffix (`Filters · 1`).
  static String filtersControlLabel(int activeCount) {
    if (activeCount <= 0) return filters;
    return '$filters · $activeCount';
  }

  /// Long-press management actions on Collection cards.
  static const editSeries = 'Edit Series';
  static const removeFromCollection = 'Remove from Collection';
  static const cancel = 'Cancel';

  /// Average figure completion across the shelf (Insights at-a-glance).
  static const shelfProgress = 'shelf progress';

  /// Inline stat chip: count + label (e.g. `11 Figures`).
  static String countLabel(int count, String label) => '$count $label';

  /// Search row suffix when a series includes a secret slot.
  static const secretFigureIncludedSuffix = 'Secret Figure included';
}
