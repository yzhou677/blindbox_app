import 'package:blindbox_app/features/catalog/search/catalog_search_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kCatalogSearchHistoryPrefsKey = 'catalog_search_history_v1';

/// SharedPreferences read/write for any search-history prefs key.
abstract final class SearchHistoryPrefsStorage {
  static Future<List<String>> load(String prefsKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    return CatalogSearchHistoryCodec.tryDecode(raw);
  }

  static Future<void> save(String prefsKey, List<String> queries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefsKey,
      CatalogSearchHistoryCodec.encode(queries),
    );
  }

  static Future<void> clear(String prefsKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }
}

/// Thin SharedPreferences read/write wrapper for catalog search history.
///
/// No business logic — deduplication and capping live in
/// [CatalogSearchHistoryRules]. This class only converts between the prefs
/// string and `List<String>`.
abstract final class CatalogSearchHistoryStorage {
  /// Loads the persisted history. Returns `[]` when nothing is stored or on
  /// corrupt data.
  static Future<List<String>> load() async =>
      SearchHistoryPrefsStorage.load(kCatalogSearchHistoryPrefsKey);

  /// Saves [queries] to SharedPreferences. Replaces any prior value.
  static Future<void> save(List<String> queries) async =>
      SearchHistoryPrefsStorage.save(kCatalogSearchHistoryPrefsKey, queries);

  /// Removes the prefs key entirely (used in tests).
  static Future<void> clear() async =>
      SearchHistoryPrefsStorage.clear(kCatalogSearchHistoryPrefsKey);
}
