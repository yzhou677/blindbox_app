import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_result.dart';

/// Local, offline catalog search over a [CatalogSeedBundle].
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
    final q = normalizeCatalogSearchQuery(rawQuery);
    if (q.isEmpty) return [];

    final scored = <_ScoredResult>[];
    for (final fig in _figures) {
      final rank = _bestRank(fig, q);
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

  _Rank? _bestRank(CatalogFigure fig, String q) {
    _Rank? best;

    void take(_Rank candidate) {
      if (best == null || candidate.isBetterThan(best!)) {
        best = candidate;
      }
    }

    final figureNorm = normalizeCatalogSearchQuery(fig.displayName);
    if (figureNorm == q) {
      take(const _Rank(_tierExactFigure, 0));
    } else if (q.isNotEmpty && figureNorm.contains(q)) {
      take(_Rank(_tierFigureSubstring, figureNorm.indexOf(q)));
    }

    final series = _seriesById[fig.seriesId];
    if (series != null) {
      final seriesNorm = normalizeCatalogSearchQuery(series.displayName);
      if (q.isNotEmpty && seriesNorm.contains(q)) {
        take(_Rank(_tierSeries, seriesNorm.indexOf(q)));
      }
    }

    final ip = _ipById[fig.ipId];
    if (ip != null) {
      final ipNorm = normalizeCatalogSearchQuery(ip.displayName);
      if (q.isNotEmpty && ipNorm.contains(q)) {
        take(_Rank(_tierIpName, ipNorm.indexOf(q)));
      }
      for (final alias in ip.aliases) {
        final a = normalizeCatalogSearchQuery(alias);
        if (q.isNotEmpty && a.contains(q)) {
          take(_Rank(_tierAlias, a.indexOf(q)));
        }
      }
    }

    final brand = _brandById[fig.brandId];
    if (brand != null) {
      final brandNorm = normalizeCatalogSearchQuery(brand.displayName);
      if (q.isNotEmpty && brandNorm.contains(q)) {
        take(_Rank(_tierAlias, brandNorm.indexOf(q)));
      }
      for (final alias in brand.aliases) {
        final a = normalizeCatalogSearchQuery(alias);
        if (q.isEmpty) continue;
        if (a.contains(q)) {
          take(_Rank(_tierAlias, a.indexOf(q)));
        }
      }
    }

    return best;
  }

  static int _compareScored(_ScoredResult a, _ScoredResult b) {
    final byRank = a.rank.compareTo(b.rank);
    if (byRank != 0) return byRank;
    final bySort = a.sortOrder.compareTo(b.sortOrder);
    if (bySort != 0) return bySort;
    return a.figureId.compareTo(b.figureId);
  }
}

/// Lowercase, trim, collapse internal whitespace (deterministic substring search).
String normalizeCatalogSearchQuery(String raw) {
  var s = raw.trim().toLowerCase();
  if (s.isEmpty) return '';
  return s.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).join(' ');
}

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
