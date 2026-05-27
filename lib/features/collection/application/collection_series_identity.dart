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

/// How a catalog-facing surface matched a shelf row.
///
/// Ownership is **series-entity specific**. Brand/IP taxonomy ids are never
/// sufficient on their own (see [resolveCollectionSeriesOwnership]).
enum CollectionSeriesOwnershipMatchKind {
  /// Shelf [ShelfSeries.catalogTemplateId] (or row id) equals catalog/drop key.
  exactCatalogTemplate,

  /// Canonicalized display [series name + brand] both match a shelf row.
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

/// Shared ownership matcher for Home/Discovery/Search surfaces against Collection.
///
/// ## Fields that participate in matching
///
/// | Input | Used for |
/// |-------|----------|
/// | [catalogTemplateId], [alternateCatalogTemplateIds] | Exact template/drop id (step 1) |
/// | [seriesName] | Canonical series leg (step 2) |
/// | [brandName] | Canonical brand leg (step 2) |
/// | [taxonomyBrandId], [taxonomyIpId] | **Not used** for owned=true (metadata only at call sites) |
///
/// Shelf row fields: [ShelfSeries.catalogTemplateId], [ShelfSeries.id],
/// [ShelfSeries.name], [ShelfSeries.brand].
///
/// ## Precedence (first hit wins)
///
/// 1. **Exact catalog template** — `catalogTemplateId` / alternates vs
///    `ShelfSeries.catalogTemplateId` or shelf row `id`.
/// 2. **Canonical brand + series** — both canonicalized strings must match the
///    same shelf row. Custom user entries without a template id rely on this.
///
/// ## What never produces owned=true
///
/// - Taxonomy brand id alone
/// - Taxonomy IP / creator id alone
/// - Brand + IP without series name equality
/// - Same maker universe with a different series title
///
/// False-negative (custom entry not linked) is acceptable; false-positive
/// (whole IP marked owned) is not.
CollectionSeriesOwnershipMatch resolveCollectionSeriesOwnership({
  required CollectionSnapshot snapshot,
  required String catalogTemplateId,
  Iterable<String> alternateCatalogTemplateIds = const [],
  required String seriesName,
  required String brandName,
  String? taxonomyBrandId,
  String? taxonomyIpId,
}) {
  // taxonomyBrandId / taxonomyIpId: not used for owned=true (see class doc).

  final templateKeys = <String>{
    catalogTemplateId.trim(),
    ...alternateCatalogTemplateIds.map((e) => e.trim()),
  }..removeWhere((k) => k.isEmpty);
  final canonicalSeries = canonicalizeCollectionIdentity(seriesName);
  final canonicalBrand = canonicalizeCollectionIdentity(brandName);

  // 1) Exact catalog/drop template key match (series-entity specific).
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

  // 2) Canonical brand + series name (both required — not IP/universe level).
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
