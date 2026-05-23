import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/features/market/application/market_listing_title_normalizer.dart';
import 'package:flutter/foundation.dart';

/// Which catalog field produced a token hit.
enum CatalogTokenSource {
  figureName,
  seriesName,
  seriesAlias,
  ipName,
  ipAlias,
  brandName,
  brandAlias,
}

@immutable
class CatalogTokenHit {
  const CatalogTokenHit({
    required this.token,
    required this.figureId,
    required this.seriesId,
    required this.brandId,
    required this.ipId,
    required this.source,
    required this.isSecret,
    required this.sortOrder,
  });

  final String token;
  final String figureId;
  final String seriesId;
  final String brandId;
  final String ipId;
  final CatalogTokenSource source;
  final bool isSecret;
  final int sortOrder;
}

/// Rank tier — mirrors [CatalogSearchService] (1 = best).
@immutable
class CatalogFigureCandidate {
  const CatalogFigureCandidate({
    required this.figureId,
    required this.seriesId,
    required this.brandId,
    required this.ipId,
    required this.tier,
    required this.indexInHaystack,
    required this.matchedToken,
    required this.source,
    required this.isSecret,
    required this.sortOrder,
  });

  final String figureId;
  final String seriesId;
  final String brandId;
  final String ipId;
  final int tier;
  final int indexInHaystack;
  final String matchedToken;
  final CatalogTokenSource source;
  final bool isSecret;
  final int sortOrder;

  bool isBetterThan(CatalogFigureCandidate other) {
    if (tier != other.tier) return tier < other.tier;
    if (indexInHaystack != other.indexInHaystack) {
      return indexInHaystack < other.indexInHaystack;
    }
    if (sortOrder != other.sortOrder) return sortOrder < other.sortOrder;
    return figureId.compareTo(other.figureId) < 0;
  }
}

/// Offline index of catalog tokens for marketplace title matching.
class CatalogIdentityIndex {
  CatalogIdentityIndex._(this._figuresById, this._seriesById);

  factory CatalogIdentityIndex.fromBundle(CatalogSeedBundle bundle) {
    final seriesById = {for (final s in bundle.series) s.id: s};
    final ipById = {for (final i in bundle.ips) i.id: i};
    final brandById = {for (final b in bundle.brands) b.id: b};
    final figuresById = <String, CatalogFigure>{
      for (final f in bundle.figures) f.id: f,
    };

    final hits = <CatalogTokenHit>[];

    void register({
      required String rawToken,
      required CatalogFigure figure,
      required CatalogTokenSource source,
    }) {
      final token = MarketListingTitleNormalizer.normalizeForMatching(rawToken);
      if (token.isEmpty) return;
      hits.add(
        CatalogTokenHit(
          token: token,
          figureId: figure.id,
          seriesId: figure.seriesId,
          brandId: figure.brandId,
          ipId: figure.ipId,
          source: source,
          isSecret: figure.isSecret,
          sortOrder: figure.sortOrder,
        ),
      );
    }

    for (final fig in bundle.figures) {
      register(
        rawToken: fig.displayName,
        figure: fig,
        source: CatalogTokenSource.figureName,
      );

      final series = seriesById[fig.seriesId];
      if (series != null) {
        register(
          rawToken: series.displayName,
          figure: fig,
          source: CatalogTokenSource.seriesName,
        );
        for (final alias in series.aliases) {
          register(
            rawToken: alias,
            figure: fig,
            source: CatalogTokenSource.seriesAlias,
          );
        }
      }

      final ip = ipById[fig.ipId];
      if (ip != null) {
        register(
          rawToken: ip.displayName,
          figure: fig,
          source: CatalogTokenSource.ipName,
        );
        for (final alias in ip.aliases) {
          register(
            rawToken: alias,
            figure: fig,
            source: CatalogTokenSource.ipAlias,
          );
        }
      }

      final brand = brandById[fig.brandId];
      if (brand != null) {
        register(
          rawToken: brand.displayName,
          figure: fig,
          source: CatalogTokenSource.brandName,
        );
        for (final alias in brand.aliases) {
          register(
            rawToken: alias,
            figure: fig,
            source: CatalogTokenSource.brandAlias,
          );
        }
      }
    }

    return CatalogIdentityIndex._(figuresById, seriesById).._hits = hits;
  }

  final Map<String, CatalogFigure> _figuresById;
  final Map<String, CatalogSeries> _seriesById;
  late final List<CatalogTokenHit> _hits;

  static const int tierExactFigure = 1;
  static const int tierFigureSubstring = 2;
  static const int tierSeries = 3;
  static const int tierIpName = 4;
  static const int tierAlias = 5;

  /// Best figure candidate for [normalizedTitle], or null when nothing scores.
  CatalogFigureCandidate? bestFigureMatch(
    String normalizedTitle, {
    String? constrainBrandId,
    String? constrainIpId,
  }) {
    if (normalizedTitle.isEmpty) return null;

    final candidates = <String, CatalogFigureCandidate>{};

    for (final hit in _hits) {
      if (constrainBrandId != null && hit.brandId != constrainBrandId) continue;
      if (constrainIpId != null && hit.ipId != constrainIpId) continue;

      final tierAndIndex = _scoreToken(normalizedTitle, hit.token, hit.source);
      if (tierAndIndex == null) continue;

      final (tier, index) = tierAndIndex;
      final next = CatalogFigureCandidate(
        figureId: hit.figureId,
        seriesId: hit.seriesId,
        brandId: hit.brandId,
        ipId: hit.ipId,
        tier: tier,
        indexInHaystack: index,
        matchedToken: hit.token,
        source: hit.source,
        isSecret: hit.isSecret,
        sortOrder: hit.sortOrder,
      );

      final prev = candidates[hit.figureId];
      if (prev == null || next.isBetterThan(prev)) {
        candidates[hit.figureId] = next;
      }
    }

    if (candidates.isEmpty) return null;

    final sorted = candidates.values.toList()
      ..sort((a, b) => a.isBetterThan(b) ? -1 : (b.isBetterThan(a) ? 1 : 0));

    final best = sorted.first;
    if (sorted.length > 1) {
      final second = sorted[1];
      if (best.tier == second.tier && best.indexInHaystack == second.indexInHaystack) {
        return null;
      }
    }
    return best;
  }

  CatalogFigure? figureById(String id) => _figuresById[id];

  CatalogSeries? seriesById(String id) => _seriesById[id];

  (int tier, int index)? _scoreToken(
    String haystack,
    String token,
    CatalogTokenSource source,
  ) {
    if (token.isEmpty) return null;

    final tierFromSource = switch (source) {
      CatalogTokenSource.figureName => () {
        if (haystack == token) return (tierExactFigure, 0);
        final i = haystack.indexOf(token);
        if (i >= 0) return (tierFigureSubstring, i);
        return null;
      }(),
      CatalogTokenSource.seriesName => () {
        final i = haystack.indexOf(token);
        if (i >= 0) return (tierSeries, i);
        return null;
      }(),
      CatalogTokenSource.ipName => () {
        final i = haystack.indexOf(token);
        if (i >= 0) return (tierIpName, i);
        return null;
      }(),
      CatalogTokenSource.seriesAlias ||
      CatalogTokenSource.ipAlias ||
      CatalogTokenSource.brandName ||
      CatalogTokenSource.brandAlias => () {
        final i = haystack.indexOf(token);
        if (i >= 0) return (tierAlias, i);
        return null;
      }(),
    };

    return tierFromSource;
  }
}
