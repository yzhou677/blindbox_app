import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/collection/application/catalog_series_shelf_commit.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_modal_overlays.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_shelf_cta_presentation.dart';
import 'package:blindbox_app/features/collection/widgets/catalog_series_preview_sheet.dart';
import 'package:blindbox_app/features/collection/widgets/series_figures_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the existing Series detail/preview for a recognition candidate.
///
/// Stacks above the scan sheet (same navigator) so back returns to results.
/// Does not mutate Collection — the user uses normal Own/Add controls.
Future<void> openRecognitionCandidateSeries(
  BuildContext context,
  WidgetRef ref, {
  required String seriesId,
  required String figureId,
}) async {
  final catalogSeriesId = seriesId.trim();
  final matchedFigureId = figureId.trim();
  if (catalogSeriesId.isEmpty) return;

  final snap = ref.read(collectionNotifierProvider);
  final notifier = ref.read(collectionNotifierProvider.notifier);
  final onShelf = _shelfSeriesForCatalogId(snap, catalogSeriesId);

  if (onShelf != null) {
    await showCollectibleBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      heightFraction: FeedRhythm.sheetPreviewOpenScreenFraction,
      builder: (_, scroll) => SeriesFiguresSheet(
        seriesId: onShelf.id,
        matchedFigureId: matchedFigureId.isEmpty ? null : matchedFigureId,
      ),
    );
    return;
  }

  final template = ref.read(catalogSeriesTemplateProvider(catalogSeriesId));
  if (template == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Couldn’t open that series right now.')),
    );
    return;
  }

  final shelfCta = CollectionSeriesShelfCtaPresentation.resolve(
    snapshot: snap,
    layout: CollectionSeriesShelfCtaLayout.previewSticky,
    catalogTemplateId: template.templateId,
    seriesName: template.name,
    brandName: template.brand,
    taxonomyBrandId: template.taxonomyBrandId,
    taxonomyIpId: template.taxonomyIpId,
  );

  if (!context.mounted) return;
  await showCollectionModalBottomSheet<void>(
    context: context,
    heightFraction: FeedRhythm.sheetPreviewOpenScreenFraction,
    builder: (_, scroll) => CatalogSeriesPreviewSheet(
      series: template,
      shelfCta: shelfCta,
      matchedFigureId: matchedFigureId.isEmpty ? null : matchedFigureId,
      onAdd: () => commitCatalogSeriesToShelf(notifier, template),
    ),
  );
}

ShelfSeries? _shelfSeriesForCatalogId(
  CollectionSnapshot snap,
  String catalogSeriesId,
) {
  for (final series in snap.shelfSeries) {
    if (series.catalogTemplateId == catalogSeriesId ||
        series.id == catalogSeriesId) {
      return series;
    }
  }
  return null;
}
