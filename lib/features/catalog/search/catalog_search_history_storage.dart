import 'package:blindbox_app/features/catalog/search/catalog_search_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kCatalogSearchHistoryPrefsKey = 'catalog_search_history_v1';

/// Thin SharedPreferences read/write wrapper for catalog search history.
///
/// No business logic — deduplication and capping live in
/// [CatalogSearchHistoryRules]. This class only converts between the prefs
/// string and `List<String>`.
abstract final class CatalogSearchHistoryStorage {
  /// Loads the persisted history. Returns `[]` when nothing is stored or on
  /// corrupt data.
  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kCatalogSearchHistoryPrefsKey);
    return CatalogSearchHistoryCodec.tryDecode(raw);
  }

  /// Saves [queries] to SharedPreferences. Replaces any prior value.
  static Future<void> save(List<String> queries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kCatalogSearchHistoryPrefsKey,
      CatalogSearchHistoryCodec.encode(queries),
    );
  }

  /// Removes the prefs key entirely (used in tests).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kCatalogSearchHistoryPrefsKey);
  }
}
