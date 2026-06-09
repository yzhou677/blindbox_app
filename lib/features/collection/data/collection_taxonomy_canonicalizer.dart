import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart';
import 'package:blindbox_app/features/market/taxonomy/brand_taxonomy_registry.dart';
import 'package:blindbox_app/features/market/taxonomy/ip_taxonomy_registry.dart';
import 'package:flutter/foundation.dart';

/// Save-time taxonomy resolution for custom collection series (create + future edit).
@immutable
class CanonicalResult {
  const CanonicalResult({
    required this.displayLabel,
    required this.taxonomyId,
    required this.matchedRegistry,
  });

  final String displayLabel;
  final String taxonomyId;
  final bool matchedRegistry;
}

@immutable
class _TaxonRef {
  const _TaxonRef({required this.id, required this.displayName});

  final String id;
  final String displayName;
}

/// Exact normalized match against [BrandTaxonomyRegistry] / [IpTaxonomyRegistry].
abstract final class CollectionTaxonomyCanonicalizer {
  static Map<String, _TaxonRef>? _brandIndex;
  static Map<String, _TaxonRef>? _ipIndex;
  static Set<String>? _ambiguousBrandKeys;
  static Set<String>? _ambiguousIpKeys;

  static CanonicalResult resolveBrandFromUserInput(String? rawBrand) {
    final trimmed = rawBrand?.trim() ?? '';
    if (trimmed.isEmpty) {
      return const CanonicalResult(
        displayLabel: 'Independent',
        taxonomyId: CustomSeriesConventions.independentBrandId,
        matchedRegistry: false,
      );
    }

    _ensureIndexes();
    return _resolve(trimmed, _brandIndex!, _ambiguousBrandKeys!, _brandFallback);
  }

  static CanonicalResult resolveIpFromUserInput(String? rawIp) {
    final trimmed = rawIp?.trim() ?? '';
    if (trimmed.isEmpty) {
      return CanonicalResult(
        displayLabel: trimmed,
        taxonomyId: CustomSeriesConventions.slugId(trimmed, fallback: 'custom_ip'),
        matchedRegistry: false,
      );
    }

    _ensureIndexes();
    return _resolve(trimmed, _ipIndex!, _ambiguousIpKeys!, _ipFallback);
  }

  static CanonicalResult _resolve(
    String trimmed,
    Map<String, _TaxonRef> index,
    Set<String> ambiguousKeys,
    CanonicalResult Function(String trimmed) fallback,
  ) {
    final key = normalizeCollectionFacetFilterKey(trimmed);
    if (key.isEmpty || ambiguousKeys.contains(key)) {
      return fallback(trimmed);
    }

    final hit = index[key];
    if (hit != null) {
      return CanonicalResult(
        displayLabel: hit.displayName,
        taxonomyId: hit.id,
        matchedRegistry: true,
      );
    }

    return fallback(trimmed);
  }

  static CanonicalResult _brandFallback(String trimmed) {
    return CanonicalResult(
      displayLabel: trimmed,
      taxonomyId: CustomSeriesConventions.brandIdFromDisplay(trimmed),
      matchedRegistry: false,
    );
  }

  static CanonicalResult _ipFallback(String trimmed) {
    return CanonicalResult(
      displayLabel: trimmed,
      taxonomyId: CustomSeriesConventions.slugId(trimmed, fallback: 'custom_ip'),
      matchedRegistry: false,
    );
  }

  static void _ensureIndexes() {
    if (_brandIndex != null && _ipIndex != null) return;

    final brandBuilt = _buildIndex(
      [
        for (final b in BrandTaxonomyRegistry.all)
          (
            id: b.id,
            displayName: b.displayName,
            aliases: b.aliases,
          ),
      ],
      label: 'brand',
    );
    _brandIndex = brandBuilt.index;
    _ambiguousBrandKeys = brandBuilt.ambiguousKeys;

    final ipBuilt = _buildIndex(
      [
        for (final ip in IpTaxonomyRegistry.all)
          (
            id: ip.id,
            displayName: ip.displayName,
            aliases: ip.aliases,
          ),
      ],
      label: 'ip',
    );
    _ipIndex = ipBuilt.index;
    _ambiguousIpKeys = ipBuilt.ambiguousKeys;
  }

  static ({Map<String, _TaxonRef> index, Set<String> ambiguousKeys}) _buildIndex(
    List<({String id, String displayName, List<String> aliases})> entries, {
    required String label,
  }) {
    final index = <String, _TaxonRef>{};
    final ambiguousKeys = <String>{};

    void register(String token, _TaxonRef ref) {
      final key = normalizeCollectionFacetFilterKey(token);
      if (key.isEmpty) return;

      if (ambiguousKeys.contains(key)) return;

      final existing = index[key];
      if (existing != null) {
        if (existing.id != ref.id) {
          ambiguousKeys.add(key);
          index.remove(key);
        }
        return;
      }

      index[key] = ref;
    }

    for (final entry in entries) {
      final ref = _TaxonRef(id: entry.id, displayName: entry.displayName);
      register(entry.id, ref);
      register(entry.displayName, ref);
      for (final alias in entry.aliases) {
        register(alias, ref);
      }
    }

    if (kDebugMode && ambiguousKeys.isNotEmpty) {
      debugPrint(
        'CollectionTaxonomyCanonicalizer: ambiguous $label keys: $ambiguousKeys',
      );
    }

    return (index: index, ambiguousKeys: ambiguousKeys);
  }

  @visibleForTesting
  static void resetIndexesForTest() {
    _brandIndex = null;
    _ipIndex = null;
    _ambiguousBrandKeys = null;
    _ambiguousIpKeys = null;
  }

  @visibleForTesting
  static Set<String> ambiguousBrandKeysForTest() {
    _ensureIndexes();
    return Set<String>.unmodifiable(_ambiguousBrandKeys!);
  }

  @visibleForTesting
  static Set<String> ambiguousIpKeysForTest() {
    _ensureIndexes();
    return Set<String>.unmodifiable(_ambiguousIpKeys!);
  }
}
