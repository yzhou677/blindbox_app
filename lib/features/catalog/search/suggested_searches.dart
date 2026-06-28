import 'dart:math';

/// One curated starter search.
///
/// [query] is committed to the field, search, and history.
/// [display] is the row label — when null, [displayLabel] falls back to [query].
///
/// Keep the pool as [SuggestedSearch] (not raw strings) so i18n can later supply
/// localized [display] while [query] stays catalog/search-stable.
class SuggestedSearch {
  const SuggestedSearch({
    required this.query,
    this.display,
  });

  final String query;
  final String? display;

  String get displayLabel => display ?? query;
}

/// Curated starter-query pool shown when search history is empty.
///
/// Shared by Catalog and Market search — not personalized, not remote.
/// UI shows [kSuggestedSearchesDisplayCount] items picked via [pickDisplayedSuggestedSearches].
const List<SuggestedSearch> kSuggestedSearches = [
  SuggestedSearch(query: 'Labubu'),
  SuggestedSearch(query: 'Crybaby'),
  SuggestedSearch(query: 'Skullpanda'),
  SuggestedSearch(query: 'Dimoo'),
  SuggestedSearch(query: 'Nommi'),
  SuggestedSearch(query: 'Hirono'),
  SuggestedSearch(query: 'Molly'),
  SuggestedSearch(query: 'Pucky'),
  SuggestedSearch(query: 'Baby Three'),
  SuggestedSearch(query: 'Nyota'),
];

const int kSuggestedSearchesDisplayCount = 5;

/// Random [kSuggestedSearchesDisplayCount] items from [kSuggestedSearches].
List<SuggestedSearch> pickDisplayedSuggestedSearches([Random? random]) {
  final shuffled = List<SuggestedSearch>.from(kSuggestedSearches)
    ..shuffle(random ?? Random());
  return shuffled.take(kSuggestedSearchesDisplayCount).toList();
}
