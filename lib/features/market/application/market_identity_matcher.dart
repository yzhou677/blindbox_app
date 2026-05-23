import 'package:blindbox_app/features/market/application/market_listing_title_normalizer.dart';
import 'package:blindbox_app/features/market/data/catalog_identity_index.dart';
import 'package:blindbox_app/features/market/domain/market_identity_match.dart';
import 'package:blindbox_app/features/market/domain/market_match_confidence.dart';
import 'package:blindbox_app/features/market/taxonomy/taxonomy_resolver.dart';

/// Maps noisy marketplace listing titles into canonical catalog identity references.
class MarketIdentityMatcher {
  MarketIdentityMatcher(
    this._index, {
    TitleTaxonomyResolver? resolver,
  }) : _resolver = resolver ?? const TitleTaxonomyResolver();

  final CatalogIdentityIndex _index;
  final TitleTaxonomyResolver _resolver;

  static const Set<String> _secretTokens = {
    'SECRET',
    'CHASE',
    '隐藏',
    'HIDDEN',
    'RARE',
  };

  MarketIdentityMatch match(
    String rawTitle, {
    String? hintBrandId,
    String? hintIpId,
  }) {
    final normalized = MarketListingTitleNormalizer.normalizeForMatching(rawTitle);
    final titleTokens = MarketListingTitleNormalizer.tokenize(normalized);

    if (normalized.isEmpty) {
      return MarketIdentityMatch.unresolved();
    }

    var source = 'title';
    String? brandId = _emptyToNull(hintBrandId);
    String? ipId = _emptyToNull(hintIpId);
    if (brandId != null || ipId != null) {
      source = 'wire_hint';
    }

    final candidate = _index.bestFigureMatch(
      normalized,
      constrainBrandId: brandId,
      constrainIpId: ipId,
    );

    if (candidate != null) {
      brandId ??= candidate.brandId;
      ipId ??= candidate.ipId;
      var confidence = _confidenceForTier(candidate.tier);
      var score = _scoreForConfidence(confidence);

      if (_titleSuggestsSecret(titleTokens) && candidate.isSecret) {
        confidence = _bumpConfidence(confidence);
        score = _scoreForConfidence(confidence);
      }

      final aliases = [candidate.matchedToken];
      return MarketIdentityMatch(
        matchedBrandId: brandId,
        matchedIpId: ipId,
        matchedSeriesId: candidate.seriesId,
        matchedFigureId: candidate.figureId,
        confidence: confidence,
        score: score,
        matchedAliases: aliases,
        normalizationSource: source,
        unresolvedTokens: _unresolved(titleTokens, aliases),
      );
    }

    // Ambiguous figure tie or no hit — brand/IP via registry + wire hints only.
    final taxonomy = _resolver.resolve(rawTitle);
    if (brandId == null &&
        taxonomy.brandId != null &&
        taxonomy.confidence >= TitleTaxonomyResolver.minConfidenceForBrandOnly) {
      brandId = taxonomy.brandId;
      ipId ??= taxonomy.ipId;
      source = source == 'wire_hint' ? 'wire_hint+registry' : 'registry';
    }

    if (brandId != null || ipId != null) {
      return MarketIdentityMatch(
        matchedBrandId: brandId,
        matchedIpId: ipId,
        matchedSeriesId: null,
        confidence: MarketMatchConfidence.low,
        score: _scoreForConfidence(MarketMatchConfidence.low),
        matchedAliases: const [],
        normalizationSource: source,
        unresolvedTokens: titleTokens,
      );
    }

    return MarketIdentityMatch.unresolved(
      unresolvedTokens: titleTokens,
      normalizationSource: source,
    );
  }

  static String? _emptyToNull(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  static bool _titleSuggestsSecret(List<String> tokens) {
    for (final t in tokens) {
      if (_secretTokens.contains(t)) return true;
    }
    return false;
  }

  static MarketMatchConfidence _confidenceForTier(int tier) {
    return switch (tier) {
      CatalogIdentityIndex.tierExactFigure => MarketMatchConfidence.exact,
      CatalogIdentityIndex.tierFigureSubstring => MarketMatchConfidence.high,
      CatalogIdentityIndex.tierSeries => MarketMatchConfidence.medium,
      CatalogIdentityIndex.tierIpName => MarketMatchConfidence.medium,
      _ => MarketMatchConfidence.low,
    };
  }

  static MarketMatchConfidence _bumpConfidence(MarketMatchConfidence c) {
    return switch (c) {
      MarketMatchConfidence.none => MarketMatchConfidence.low,
      MarketMatchConfidence.low => MarketMatchConfidence.medium,
      MarketMatchConfidence.medium => MarketMatchConfidence.high,
      MarketMatchConfidence.high => MarketMatchConfidence.exact,
      MarketMatchConfidence.exact => MarketMatchConfidence.exact,
    };
  }

  static double _scoreForConfidence(MarketMatchConfidence c) {
    return switch (c) {
      MarketMatchConfidence.exact => 1.0,
      MarketMatchConfidence.high => 0.85,
      MarketMatchConfidence.medium => 0.6,
      MarketMatchConfidence.low => 0.4,
      MarketMatchConfidence.none => 0,
    };
  }

  static List<String> _unresolved(
    List<String> titleTokens,
    List<String> matchedAliases,
  ) {
    if (matchedAliases.isEmpty) return titleTokens;
    final covered = <String>{};
    for (final alias in matchedAliases) {
      for (final part in alias.split(RegExp(r'\s+'))) {
        if (part.isNotEmpty) covered.add(part);
      }
    }
    return [
      for (final t in titleTokens)
        if (!covered.contains(t)) t,
    ];
  }
}
