import 'package:blindbox_app/features/collection/domain/collection_domain.dart';

/// Deterministic canonicalization for cross-surface ownership identity.
///
/// Rules:
/// - lowercase
/// - trim
/// - remove spaces/underscores/hyphens
/// - keep only [a-z0-9]
String canonicalizeCollectionIdentity(String raw) {
  final lower = raw.trim().toLowerCase();
  if (lower.isEmpty) return '';
  final compact = lower
      .replaceAll(' ', '')
      .replaceAll('_', '')
      .replaceAll('-', '');
  return compact.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

enum CollectionSeriesOwnershipMatchKind {
  exactCatalogTemplate,
  taxonomyBrandIp,
  canonicalBrandSeries,
}

class CollectionSeriesOwnershipMatch {
  const CollectionSeriesOwnershipMatch._({
    required this.owned,
    this.kind,
    this.matchedSeriesId,
    this.matchedCatalogTemplateId,
  });

  const CollectionSeriesOwnershipMatch.notOwned() : this._(owned: false);

  const CollectionSeriesOwnershipMatch.owned({
    required CollectionSeriesOwnershipMatchKind kind,
    required String matchedSeriesId,
    String? matchedCatalogTemplateId,
  }) : this._(
          owned: true,
          kind: kind,
          matchedSeriesId: matchedSeriesId,
          matchedCatalogTemplateId: matchedCatalogTemplateId,
        );

  final bool owned;
  final CollectionSeriesOwnershipMatchKind? kind;
  final String? matchedSeriesId;
  final String? matchedCatalogTemplateId;

  /// Only exact catalog-template matches should be removable via release CTA.
  bool get removableViaReleaseCta =>
      kind == CollectionSeriesOwnershipMatchKind.exactCatalogTemplate &&
      matchedCatalogTemplateId != null;
}

/// Shared ownership matcher for Home/Discovery surfaces against Collection.
CollectionSeriesOwnershipMatch resolveCollectionSeriesOwnership({
  required CollectionSnapshot snapshot,
  required String catalogTemplateId,
  Iterable<String> alternateCatalogTemplateIds = const [],
  required String seriesName,
  required String brandName,
  String? taxonomyBrandId,
  String? taxonomyIpId,
}) {
  final templateKeys = <String>{
    catalogTemplateId.trim(),
    ...alternateCatalogTemplateIds.map((e) => e.trim()),
  }..removeWhere((k) => k.isEmpty);
  final canonicalSeries = canonicalizeCollectionIdentity(seriesName);
  final canonicalBrand = canonicalizeCollectionIdentity(brandName);
  final canonicalTaxonomyBrand = canonicalizeCollectionIdentity(
    taxonomyBrandId ?? '',
  );
  final canonicalTaxonomyIp = canonicalizeCollectionIdentity(taxonomyIpId ?? '');

  // 1) Exact catalog/drop template key match (high confidence).
  for (final row in snapshot.shelfSeries) {
    final rowTemplate = row.catalogTemplateId?.trim() ?? '';
    String? matchedTemplate;
    for (final key in templateKeys) {
      if (rowTemplate == key || row.id == key) {
        matchedTemplate = key;
        break;
      }
    }
    if (matchedTemplate != null) {
      return CollectionSeriesOwnershipMatch.owned(
        kind: CollectionSeriesOwnershipMatchKind.exactCatalogTemplate,
        matchedSeriesId: row.id,
        matchedCatalogTemplateId: matchedTemplate,
      );
    }
  }

  // 2) Taxonomy match when both sides have canonical brand+ip ids.
  if (canonicalTaxonomyBrand.isNotEmpty && canonicalTaxonomyIp.isNotEmpty) {
    for (final row in snapshot.shelfSeries) {
      final rowBrand = canonicalizeCollectionIdentity(row.taxonomyBrandId ?? '');
      final rowIp = canonicalizeCollectionIdentity(row.taxonomyIpId ?? '');
      if (rowBrand.isNotEmpty &&
          rowIp.isNotEmpty &&
          rowBrand == canonicalTaxonomyBrand &&
          rowIp == canonicalTaxonomyIp) {
        return CollectionSeriesOwnershipMatch.owned(
          kind: CollectionSeriesOwnershipMatchKind.taxonomyBrandIp,
          matchedSeriesId: row.id,
        );
      }
    }
  }

  // 3) Best-effort canonical brand+series match (includes custom rows).
  if (canonicalSeries.isNotEmpty && canonicalBrand.isNotEmpty) {
    for (final row in snapshot.shelfSeries) {
      final rowSeries = canonicalizeCollectionIdentity(row.name);
      final rowBrand = canonicalizeCollectionIdentity(row.brand);
      if (rowSeries == canonicalSeries && rowBrand == canonicalBrand) {
        return CollectionSeriesOwnershipMatch.owned(
          kind: CollectionSeriesOwnershipMatchKind.canonicalBrandSeries,
          matchedSeriesId: row.id,
        );
      }
    }
  }

  return const CollectionSeriesOwnershipMatch.notOwned();
}
