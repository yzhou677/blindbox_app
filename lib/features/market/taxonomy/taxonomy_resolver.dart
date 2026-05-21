import 'package:blindbox_app/features/market/taxonomy/brand_taxonomy_registry.dart';
import 'package:blindbox_app/features/market/taxonomy/ip_taxonomy_registry.dart';
import 'package:blindbox_app/features/market/taxonomy/taxonomy_models.dart';
import 'package:blindbox_app/features/market/taxonomy/taxonomy_title_normalizer.dart';

/// Title-first taxonomy resolution: registry data + deterministic substring rules only.
///
/// Pure (no I/O, no Flutter, no Riverpod). Expand coverage via registries, not edits here.
class TitleTaxonomyResolver {
  const TitleTaxonomyResolver();

  /// High confidence when a single best IP alias hit wins by length over runners-up.
  static const double confidenceIp = 0.9;

  /// Medium confidence when only a brand string hits (no confident IP).
  static const double confidenceBrandOnly = 0.55;

  /// Mapper: accept brand + IP from resolver at or above this value.
  static const double minConfidenceForTaxonomyIds = 0.75;

  /// Mapper: accept brand-only when IP is null and confidence is at or above this value.
  static const double minConfidenceForBrandOnly = 0.5;

  /// Brand-only path ignores very short aliases to reduce substring false positives
  /// (IP path still uses all aliases).
  static const int _minBrandOnlyAliasLength = 6;

  TaxonomyMatch resolve(String rawTitle) {
    final norm = TaxonomyTitleNormalizer.normalize(rawTitle);
    if (norm.isEmpty) return TaxonomyMatch.unknown;

    final ipHit = _resolveIp(norm);
    if (ipHit != null) {
      return TaxonomyMatch(
        brandId: ipHit.brandId,
        ipId: ipHit.ipId,
        confidence: confidenceIp,
      );
    }

    final brandHit = _resolveBrandOnly(norm);
    if (brandHit != null) {
      return TaxonomyMatch(
        brandId: brandHit,
        ipId: null,
        confidence: confidenceBrandOnly,
      );
    }

    return TaxonomyMatch.unknown;
  }

  /// Returns best unique IP by longest matching alias length; null if ambiguous or none.
  _IpWin? _resolveIp(String norm) {
    final scores = <_IpScore>[];
    for (final ip in IpTaxonomyRegistry.all) {
      var best = 0;
      for (final al in ip.aliases) {
        final token = TaxonomyTitleNormalizer.normalize(al);
        if (token.isEmpty) continue;
        if (norm.contains(token)) {
          if (token.length > best) best = token.length;
        }
      }
      for (final kw in ip.searchKeywords) {
        final token = TaxonomyTitleNormalizer.normalize(kw);
        if (token.isEmpty) continue;
        if (norm.contains(token)) {
          if (token.length > best) best = token.length;
        }
      }
      if (best > 0) {
        scores.add(_IpScore(ipId: ip.id, brandId: ip.brandId, score: best));
      }
    }
    if (scores.isEmpty) return null;
    scores.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      return a.ipId.compareTo(b.ipId);
    });
    final top = scores.first;
    final second = scores.length > 1 ? scores[1].score : 0;
    if (second == 0 || top.score > second) {
      return _IpWin(ipId: top.ipId, brandId: top.brandId);
    }
    return null;
  }

  /// Longest unique brand alias (short aliases skipped — see [_minBrandOnlyAliasLength]).
  String? _resolveBrandOnly(String norm) {
    final scores = <_BrandScore>[];
    for (final b in BrandTaxonomyRegistry.all) {
      var best = 0;
      for (final al in b.aliases) {
        final token = TaxonomyTitleNormalizer.normalize(al);
        if (token.length < _minBrandOnlyAliasLength) continue;
        // Prefer "DREAMS INC" over bare "DREAMS" to avoid common-word substring hits.
        if (token == 'DREAMS') continue;
        if (norm.contains(token)) {
          if (token.length > best) best = token.length;
        }
      }
      if (best > 0) {
        scores.add(_BrandScore(brandId: b.id, score: best));
      }
    }
    if (scores.isEmpty) return null;
    scores.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      return a.brandId.compareTo(b.brandId);
    });
    final top = scores.first;
    final second = scores.length > 1 ? scores[1].score : 0;
    if (second == 0 || top.score > second) {
      return top.brandId;
    }
    return null;
  }
}

class _IpScore {
  const _IpScore({required this.ipId, required this.brandId, required this.score});
  final String ipId;
  final String brandId;
  final int score;
}

class _BrandScore {
  const _BrandScore({required this.brandId, required this.score});
  final String brandId;
  final int score;
}

class _IpWin {
  const _IpWin({required this.ipId, required this.brandId});
  final String ipId;
  final String brandId;
}
