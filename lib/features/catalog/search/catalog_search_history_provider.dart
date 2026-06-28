import 'package:blindbox_app/features/catalog/search/catalog_search_history.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_history_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory + persisted search history for catalog search.
///
/// Uses [Notifier] (Riverpod 2.x) to match the project's existing notifier
/// style ([CollectionNotifier], [MarketSearchBrowseNotifier]).
///
/// State is `List<String>` — most-recent-first, max
/// [kCatalogSearchHistoryMaxEntries] entries, no duplicates.
///
/// Persistence is fire-and-forget: UI updates optimistically and the prefs
/// write runs unawaited, matching the project's offline-first pattern.
final catalogSearchHistoryProvider =
    NotifierProvider<CatalogSearchHistoryNotifier, List<String>>(
  CatalogSearchHistoryNotifier.new,
);

class CatalogSearchHistoryNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    _loadFromStorage();
    return const [];
  }

  Future<void> _loadFromStorage() async {
    final loaded = await CatalogSearchHistoryStorage.load();
    if (state != loaded) {
      state = loaded;
    }
  }

  /// Records [query] at the top of the history (deduplicates and promotes).
  /// Ignores blank queries.
  void add(String query) {
    final updated = CatalogSearchHistoryRules.add(state, query);
    if (updated == state) return;
    state = updated;
    _persist();
  }

  /// Removes a single [query] from history.
  void remove(String query) {
    final updated = CatalogSearchHistoryRules.remove(state, query);
    if (updated.length == state.length) return;
    state = updated;
    _persist();
  }

  /// Clears all history.
  void clearAll() {
    if (state.isEmpty) return;
    state = const [];
    _persist();
  }

  void _persist() {
    // Fire-and-forget — UI already has the new state.
    CatalogSearchHistoryStorage.save(state);
  }
}
