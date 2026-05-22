import 'package:flutter/foundation.dart';

import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as seed_catalog;
import 'package:blindbox_app/features/catalog/search/catalog_search_result.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_service.dart';
import 'package:blindbox_app/features/collection/presentation/catalog_search_row_summary.dart';

/// One aggregated series row from catalog search (ranking follows [CatalogSearchService]).
@immutable
class CatalogSeriesSearchRow {
  const CatalogSeriesSearchRow({
    required this.seriesId,
    required this.seriesTitle,
    required this.coverImageKey,
    required this.summaryLine,
    required this.brandIpLine,
    required this.hasAnySecret,
  });

  final String seriesId;
  final String seriesTitle;
  final String coverImageKey;
  final String summaryLine;
  final String brandIpLine;
  final bool hasAnySecret;
}

class _SeriesSearchAgg {
  _SeriesSearchAgg({
    required this.firstHit,
    required this.matchedFigureNames,
    required this.hasAnySecret,
  });

  final CatalogSearchResult firstHit;
  final Set<String> matchedFigureNames;
  bool hasAnySecret;
}

/// Builds series-centric search rows — same ranking/filter as Add Series sheet.
List<CatalogSeriesSearchRow> buildCatalogSeriesSearchRows({
  required CatalogSeedBundle bundle,
  required String query,
  bool Function(String seriesId)? excludeSeriesId,
}) {
  final svc = CatalogSearchService(bundle);
  final raw = svc.search(query);
  final figureSeriesId = {for (final f in bundle.figures) f.id: f.seriesId};
  final seriesById = {for (final s in bundle.series) s.id: s};

  final order = <String>[];
  final groups = <String, _SeriesSearchAgg>{};

  for (final r in raw) {
    final sid = figureSeriesId[r.figureId];
    if (sid == null) continue;
    if (excludeSeriesId != null && excludeSeriesId(sid)) continue;

    final existing = groups[sid];
    if (existing == null) {
      order.add(sid);
      groups[sid] = _SeriesSearchAgg(
        firstHit: r,
        matchedFigureNames: {r.figureName},
        hasAnySecret: r.isSecret,
      );
    } else {
      existing.matchedFigureNames.add(r.figureName);
      existing.hasAnySecret = existing.hasAnySecret || r.isSecret;
    }
  }

  return order
      .map((sid) {
        final agg = groups[sid]!;
        final series = seriesById[sid];
        if (series == null) {
          throw StateError('Catalog seed missing series $sid');
        }
        final figureCount = _figureCountInSeries(bundle, sid);
        final summaryLine = catalogSearchRowSummary(
          figureCount: figureCount,
          hasChase: agg.hasAnySecret,
          matchedFigureNames: agg.matchedFigureNames,
        );

        return CatalogSeriesSearchRow(
          seriesId: sid,
          seriesTitle: series.displayName,
          coverImageKey: series.imageKey.trim(),
          summaryLine: summaryLine,
          brandIpLine: _brandIpLineForSeries(bundle, series),
          hasAnySecret: agg.hasAnySecret,
        );
      })
      .toList(growable: false);
}

int _figureCountInSeries(CatalogSeedBundle bundle, String seriesId) {
  var n = 0;
  for (final f in bundle.figures) {
    if (f.seriesId == seriesId) n++;
  }
  return n;
}

String _brandIpLineForSeries(
  CatalogSeedBundle bundle,
  seed_catalog.CatalogSeries series,
) {
  var brandName = series.brandId;
  for (final b in bundle.brands) {
    if (b.id == series.brandId) {
      brandName = b.displayName;
      break;
    }
  }
  var ipName = series.ipId;
  for (final i in bundle.ips) {
    if (i.id == series.ipId) {
      ipName = i.displayName;
      break;
    }
  }
  return '$brandName · $ipName';
}
