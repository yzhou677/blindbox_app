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
