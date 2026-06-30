import 'dart:convert';

import 'package:blindbox_app/core/search/search_normalizer.dart';

/// Max entries kept in search history. Oldest entries are dropped when this
/// limit is reached; the list is always most-recent-first.
const int kCatalogSearchHistoryMaxEntries = 15;

/// Codec for [List<String>] stored as a JSON array under
/// [kCatalogSearchHistoryPrefsKey].
///
/// The on-disk format is intentionally minimal: `["Labubu","Crybaby"]`.
/// No timestamps, no IDs — just the ordered list of raw query strings.
///
/// Any parse error returns an empty list (defensive fallback).
abstract final class CatalogSearchHistoryCodec {
  /// Decodes a JSON string to a list of queries.
  /// Returns `[]` on null, empty, or corrupt input.
  static List<String> tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is String && item.isNotEmpty) item,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Encodes a list of queries to a JSON string.
  static String encode(List<String> queries) => jsonEncode(queries);
}

/// Applies search history business rules to an existing list.
///
/// Pure functions — no I/O, easy to test.
abstract final class CatalogSearchHistoryRules {
  /// Same pipeline as live local search ([SearchNormalizer]).
  static String normalize(String query) => SearchNormalizer.normalize(query);

  /// Returns a new list with [query] promoted to the front.
  ///
  /// * Normalises [query]; ignores empty strings.
  /// * Removes any existing occurrence (case-insensitive after normalize).
  /// * Prepends [query].
  /// * Truncates to [kCatalogSearchHistoryMaxEntries].
  static List<String> add(List<String> current, String query) {
    final q = normalize(query);
    if (q.isEmpty) return current;
    final updated = [
      q,
      for (final e in current)
        if (normalize(e) != q) e,
    ];
    if (updated.length > kCatalogSearchHistoryMaxEntries) {
      return updated.sublist(0, kCatalogSearchHistoryMaxEntries);
    }
    return updated;
  }

  /// Returns a new list without [query] (normalises before comparing).
  static List<String> remove(List<String> current, String query) {
    final q = normalize(query);
    return [for (final e in current) if (normalize(e) != q) e];
  }

  /// Returns an empty list.
  static List<String> clear() => const [];
}
