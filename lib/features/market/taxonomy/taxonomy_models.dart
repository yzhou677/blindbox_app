import 'package:flutter/foundation.dart';

/// Curated brand row (registry data only — no wire/DTO types).
@immutable
class BrandTaxonomy {
  const BrandTaxonomy({
    required this.id,
    required this.displayName,
    required this.aliases,
  });

  /// Canonical snake_case id (e.g. `pop_mart`).
  final String id;
  final String displayName;

  /// Match tokens (store UPPERCASE Latin; CJK as needed). Registry-owned only.
  final List<String> aliases;
}

/// Curated IP row under a [BrandTaxonomy.id].
@immutable
class IpTaxonomy {
  const IpTaxonomy({
    required this.id,
    required this.displayName,
    required this.brandId,
    required this.aliases,
    this.searchKeywords = const [],
  });

  final String id;
  final String displayName;

  /// Parent brand [BrandTaxonomy.id].
  final String brandId;
  final List<String> aliases;

  /// Optional extra tokens (same normalization as title). Reserved for expansion.
  final List<String> searchKeywords;
}

/// Title-first resolution result (deterministic, no I/O).
@immutable
class TaxonomyMatch {
  const TaxonomyMatch({
    required this.brandId,
    required this.ipId,
    required this.confidence,
  });

  final String? brandId;
  final String? ipId;

  /// 0 = unknown; medium ≈ brand-only; high ≈ confident IP (see resolver thresholds).
  final double confidence;

  static const TaxonomyMatch unknown = TaxonomyMatch(
    brandId: null,
    ipId: null,
    confidence: 0,
  );
}
