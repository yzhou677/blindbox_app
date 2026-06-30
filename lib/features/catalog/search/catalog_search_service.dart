import 'package:blindbox_app/core/search/search_matcher.dart';
import 'package:blindbox_app/core/search/search_normalizer.dart';
import 'package:blindbox_app/core/search/search_tokenizer.dart';
import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_result.dart';

/// Shared offline search matcher for catalog-backed surfaces (browse, add-series,
/// collection shelf, market identity). Single source of truth for figure/series/IP/
/// brand/alias token matching.
///
/// Pure Dart: no Flutter widgets, no Riverpod. Swappable later for remote/cache
/// sources by building the same bundle from JSON.
final class CatalogSearchService {
  CatalogSearchService(CatalogSeedBundle bundle)
      : _figures = bundle.figures,
        _seriesById = {for (final s in bundle.series) s.id: s},
        _ipById = {for (final i in bundle.ips) i.id: i},
        _brandById = {for (final b in bundle.brands) b.id: b};

  final List<CatalogFigure> _figures;
  final Map<String, CatalogSeries> _seriesById;
  final Map<String, CatalogIp> _ipById;
  final Map<String, CatalogBrand> _brandById;

  /// Rank tier: **1** = best (exact figure name), **5** = weakest (alias / brand text).
  static const int _tierExactFigure = 1;
  static const int _tierFigureSubstring = 2;
  static const int _tierSeries = 3;
  static const int _tierIpName = 4;
  static const int _tierAlias = 5;

  /// Returns figures that match [rawQuery], best matches first. Empty query → [].
  List<CatalogSearchResult> search(String rawQuery) {
    final tokens = SearchTokenizer.tokenize(rawQuery);
    if (tokens.isEmpty) return [];

    final normalizedFullQuery = SearchNormalizer.normalize(rawQuery);
    final scored = <_ScoredResult>[];
    for (final fig in _figures) {
      final rank = _bestRank(fig, tokens, normalizedFullQuery);
      if (rank == null) continue;
      final series = _seriesById[fig.seriesId];
      if (series == null) continue;
      scored.add(
        _ScoredResult(
          rank: rank,
          result: CatalogSearchResult(
            figureId: fig.id,
            figureName: fig.displayName,
            seriesName: series.displayName,
            brandId: fig.brandId,
            ipId: fig.ipId,
            imageKey: fig.imageKey,
            isSecret: fig.isSecret,
          ),
          sortOrder: fig.sortOrder,
          figureId: fig.id,
        ),
      );
    }

    scored.sort(_compareScored);
    return scored.map((e) => e.result).toList(growable: false);
  }

  /// Series ids with at least one figure match — for filtering shelf rows by
  /// [ShelfSeries.catalogTemplateId] without duplicating match rules.
  Set<String> matchingSeriesIds(String rawQuery) {
    final tokens = SearchTokenizer.tokenize(rawQuery);
    if (tokens.isEmpty) return const {};

    final normalizedFullQuery = SearchNormalizer.normalize(rawQuery);
    final ids = <String>{};
    for (final fig in _figures) {
      if (_bestRank(fig, tokens, normalizedFullQuery) == null) continue;
      ids.add(fig.seriesId);
    }
    return ids;
  }

  _Rank? _bestRank(
    CatalogFigure fig,
    List<String> tokens,
    String normalizedFullQuery,
  ) {
    if (!SearchMatcher.allTokensMatch(_combinedHaystack(fig), tokens)) {
      return null;
    }

    _Rank? best;

    void take(_Rank candidate) {
      if (best == null || candidate.isBetterThan(best!)) {
        best = candidate;
      }
    }

    final figureNorm = SearchNormalizer.normalize(fig.displayName);
    if (figureNorm == normalizedFullQuery) {
      take(const _Rank(_tierExactFigure, 0));
    } else if (SearchMatcher.allTokensMatch(
      SearchNormalizer.normalizeForMatch(fig.displayName),
      tokens,
    )) {
      take(_Rank(
        _tierFigureSubstring,
        SearchMatcher.earliestTokenIndex(figureNorm, tokens),
      ));
    }

    final series = _seriesById[fig.seriesId];
    if (series != null) {
      final seriesMatch = SearchNormalizer.normalizeForMatch(series.displayName);
      if (SearchMatcher.allTokensMatch(seriesMatch, tokens)) {
        take(_Rank(
          _tierSeries,
          SearchMatcher.earliestTokenIndex(seriesMatch, tokens),
        ));
      }
      for (final alias in series.aliases) {
        final a = SearchNormalizer.normalizeForMatch(alias);
        if (SearchMatcher.allTokensMatch(a, tokens)) {
          take(_Rank(_tierAlias, SearchMatcher.earliestTokenIndex(a, tokens)));
        }
      }
    }

    final ip = _ipById[fig.ipId];
    if (ip != null) {
      final ipMatch = SearchNormalizer.normalizeForMatch(ip.displayName);
      if (SearchMatcher.allTokensMatch(ipMatch, tokens)) {
        take(_Rank(
          _tierIpName,
          SearchMatcher.earliestTokenIndex(ipMatch, tokens),
        ));
      }
      for (final alias in ip.aliases) {
        final a = SearchNormalizer.normalizeForMatch(alias);
        if (SearchMatcher.allTokensMatch(a, tokens)) {
          take(_Rank(_tierAlias, SearchMatcher.earliestTokenIndex(a, tokens)));
        }
      }
    }

    final brand = _brandById[fig.brandId];
    if (brand != null) {
      final brandMatch = SearchNormalizer.normalizeForMatch(brand.displayName);
      if (SearchMatcher.allTokensMatch(brandMatch, tokens)) {
        take(_Rank(
          _tierAlias,
          SearchMatcher.earliestTokenIndex(brandMatch, tokens),
        ));
      }
      for (final alias in brand.aliases) {
        final a = SearchNormalizer.normalizeForMatch(alias);
        if (SearchMatcher.allTokensMatch(a, tokens)) {
          take(_Rank(_tierAlias, SearchMatcher.earliestTokenIndex(a, tokens)));
        }
      }
    }

    return best;
  }

  String _combinedHaystack(CatalogFigure fig) {
    final parts = <String>[fig.displayName];

    final series = _seriesById[fig.seriesId];
    if (series != null) {
      parts.add(series.displayName);
      parts.addAll(series.aliases);
    }

    final ip = _ipById[fig.ipId];
    if (ip != null) {
      parts.add(ip.displayName);
      parts.addAll(ip.aliases);
    }

    final brand = _brandById[fig.brandId];
    if (brand != null) {
      parts.add(brand.displayName);
      parts.addAll(brand.aliases);
    }

    return parts.map(SearchNormalizer.normalizeForMatch).join(' ');
  }

  static int _compareScored(_ScoredResult a, _ScoredResult b) {
    final byRank = a.rank.compareTo(b.rank);
    if (byRank != 0) return byRank;
    final bySort = a.sortOrder.compareTo(b.sortOrder);
    if (bySort != 0) return bySort;
    return a.figureId.compareTo(b.figureId);
  }
}

/// Normalized query string — delegates to [SearchNormalizer] (Search V2).
String normalizeCatalogSearchQuery(String raw) => SearchNormalizer.normalize(raw);

class _Rank {
  const _Rank(this.tier, this.indexInHaystack);

  /// 1 = best … 5 = alias / loose brand text.
  final int tier;

  /// Earlier match in normalized string sorts before later (smaller index = better).
  final int indexInHaystack;

  bool isBetterThan(_Rank o) {
    final c = compareTo(o);
    return c < 0;
  }

  int compareTo(_Rank o) {
    if (tier != o.tier) return tier.compareTo(o.tier);
    return indexInHaystack.compareTo(o.indexInHaystack);
  }
}

class _ScoredResult {
  const _ScoredResult({
    required this.rank,
    required this.result,
    required this.sortOrder,
    required this.figureId,
  });

  final _Rank rank;
  final CatalogSearchResult result;
  final int sortOrder;
  final String figureId;
}
