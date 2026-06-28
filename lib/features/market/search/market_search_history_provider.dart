import 'package:blindbox_app/features/catalog/search/catalog_search_history.dart';
import 'package:blindbox_app/features/market/search/market_search_history_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory + persisted search history for Market search.
///
/// Same rules and codec as catalog history; separate prefs key
/// ([kMarketSearchHistoryPrefsKey]).
final marketSearchHistoryProvider =
    NotifierProvider<MarketSearchHistoryNotifier, List<String>>(
  MarketSearchHistoryNotifier.new,
);

class MarketSearchHistoryNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    _loadFromStorage();
    return const [];
  }

  Future<void> _loadFromStorage() async {
    final loaded = await MarketSearchHistoryStorage.load();
    if (state != loaded) {
      state = loaded;
    }
  }

  void add(String query) {
    final updated = CatalogSearchHistoryRules.add(state, query);
    if (updated == state) return;
    state = updated;
    _persist();
  }

  void remove(String query) {
    final updated = CatalogSearchHistoryRules.remove(state, query);
    if (updated.length == state.length) return;
    state = updated;
    _persist();
  }

  void clearAll() {
    if (state.isEmpty) return;
    state = const [];
    _persist();
  }

  void _persist() {
    MarketSearchHistoryStorage.save(state);
  }
}
