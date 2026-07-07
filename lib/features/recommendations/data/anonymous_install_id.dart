import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Locally generated anonymous install identity for recommendation profiles.
abstract final class AnonymousInstallId {
  static const _prefsKey = 'recommendation_install_id_v1';
  static const _uuid = Uuid();

  static String? _memoryCache;

  static Future<String> getOrCreate() async {
    final cached = peek();
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey)?.trim();
    if (stored != null && stored.isNotEmpty) {
      _memoryCache = stored;
      return stored;
    }

    final generated = _uuid.v4();
    await prefs.setString(_prefsKey, generated);
    _memoryCache = generated;
    return generated;
  }

  static String? peek() {
    final cached = _memoryCache?.trim();
    if (cached != null && cached.isNotEmpty) return cached;
    return null;
  }

  /// Test-only reset.
  @visibleForTesting
  static void resetForTest() {
    _memoryCache = null;
  }
}
