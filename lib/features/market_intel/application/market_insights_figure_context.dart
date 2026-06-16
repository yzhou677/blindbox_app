import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/models/market_listing.dart';

/// Figure metadata shown at the top of [MarketInsightsScreen].
class MarketInsightsFigureContext {
  const MarketInsightsFigureContext({
    required this.figureName,
    required this.seriesName,
    this.imageKey,
  });

  final String figureName;
  final String seriesName;

  /// Catalog [CatalogFigure.imageKey]; null when unavailable.
  final String? imageKey;
}

/// Resolves header copy from in-memory catalog + listing metadata only.
MarketInsightsFigureContext resolveMarketInsightsFigureContext({
  required String figureId,
  MarketListing? listing,
}) {
  final trimmedFigureId = figureId.trim();
  final bundle = CatalogBundleCache.current;

  CatalogFigure? catalogFigure;
  CatalogSeries? catalogSeries;
  if (bundle != null && trimmedFigureId.isNotEmpty) {
    for (final figure in bundle.figures) {
      if (figure.id == trimmedFigureId) {
        catalogFigure = figure;
        break;
      }
    }
    if (catalogFigure != null) {
      for (final series in bundle.series) {
        if (series.id == catalogFigure.seriesId) {
          catalogSeries = series;
          break;
        }
      }
    }
  }

  final listingName = listing?.collectible.name.trim() ?? '';
  final listingSeries = listing?.collectible.series.trim() ?? '';

  final figureName = catalogFigure?.displayName.trim().isNotEmpty == true
      ? catalogFigure!.displayName.trim()
      : listingName;

  final seriesName = catalogSeries?.displayName.trim().isNotEmpty == true
      ? catalogSeries!.displayName.trim()
      : listingSeries;

  final imageKey = catalogFigure?.imageKey.trim();

  return MarketInsightsFigureContext(
    figureName: figureName.isNotEmpty ? figureName : 'Collectible',
    seriesName: seriesName,
    imageKey: imageKey != null && imageKey.isNotEmpty ? imageKey : null,
  );
}
