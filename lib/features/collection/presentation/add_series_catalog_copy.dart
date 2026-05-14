/// Wording for the catalog-backed “Add series” sheet — search vs browse states.
abstract final class AddSeriesCatalogCopy {
  static const String sheetSubtitle =
      'Search the catalog to add a series, or create your own below.';

  /// List heading: search-active reads as results; idle reads as available catalog rows.
  static String catalogListHeading({required bool searchActive}) {
    return searchActive ? 'Matching series' : 'Series to add';
  }

  static const String noSearchMatches = 'No matches for that search.';
}
