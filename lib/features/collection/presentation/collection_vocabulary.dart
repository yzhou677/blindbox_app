/// Canonical user-facing labels for the Collection module.
///
/// One name per concept — summary, insights, shelf cards, and sheets
/// should import from here instead of inventing parallel wording.
abstract final class CollectionVocabulary {
  CollectionVocabulary._();

  static const figures = 'Figures';
  static const wishlist = 'Wishlist';
  static const completedSeries = 'Completed Series';
  static const masterComplete = 'Master Complete';
  static const secretFigure = 'Secret Figure';
  static const regularFigures = 'Regular Figures';
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
