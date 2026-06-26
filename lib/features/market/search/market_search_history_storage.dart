import 'package:blindbox_app/features/catalog/search/catalog_search_history_storage.dart';

const String kMarketSearchHistoryPrefsKey = 'market_search_history_v1';

/// SharedPreferences read/write for Market search history.
abstract final class MarketSearchHistoryStorage {
  static Future<List<String>> load() async =>
      SearchHistoryPrefsStorage.load(kMarketSearchHistoryPrefsKey);

  static Future<void> save(List<String> queries) async =>
      SearchHistoryPrefsStorage.save(kMarketSearchHistoryPrefsKey, queries);

  static Future<void> clear() async =>
      SearchHistoryPrefsStorage.clear(kMarketSearchHistoryPrefsKey);
}
