import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_item.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_meta.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_figure_media.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';

List<CatalogFigureGalleryItem> catalogGalleryItemsFromCatalogSeries(
  CatalogSeries series,
) {
  return [
    for (final f in series.figures)
      _galleryItemFromRarityFields(
        id: f.templateFigureId,
        name: f.name,
        catalogImageKey: f.catalogImageKey,
        combinedRarity: f.rarity,
        isSecret: f.isSecret,
      ),
  ];
}

List<CatalogFigureGalleryItem> catalogGalleryItemsFromShelfSeries(
  ShelfSeries series,
) {
  return [
    for (final f in series.figures)
      _galleryItemFromShelfFigure(f, series),
  ];
}

String? _seriesCoverFallbackForGallery(ShelfFigure figure, ShelfSeries series) {
  final local = figure.localImageUri?.trim();
  if (local != null && local.isNotEmpty) return null;
  return ShelfFigureMedia.seriesCoverRef(series);
}

CatalogFigureGalleryItem _galleryItemFromShelfFigure(
  ShelfFigure f,
  ShelfSeries series,
) {
  final odds =
      catalogFigureGalleryNormalizeOdds(f.rarityLabel) ??
      catalogFigureGalleryNormalizeOdds(f.rarity);

  String? rarity;
  final rarityLabel = f.rarityLabel?.trim();
  if (rarityLabel != null &&
      rarityLabel.isNotEmpty &&
      !catalogFigureGalleryLabelDenotesOdds(rarityLabel)) {
    rarity = rarityLabel;
  } else {
    final shortRarity = f.rarity.trim();
    if (shortRarity.isNotEmpty &&
        shortRarity != 'Regular' &&
        !catalogFigureGalleryLabelDenotesOdds(shortRarity)) {
      rarity = shortRarity;
    }
  }

  return CatalogFigureGalleryItem(
    id: f.id,
    name: f.name,
    catalogImageKey: f.imageKey,
    localImageUri: f.localImageUri,
    seriesCoverImageUri: _seriesCoverFallbackForGallery(f, series),
    rarityLabel: rarity,
    oddsLabel: odds,
    isSecret: f.isSecret,
  );
}

List<CatalogFigureGalleryItem> catalogGalleryItemsFromSeriesRelease(
  SeriesRelease release,
) {
  return [
    for (final slot in release.lineup)
      _galleryItemFromRarityFields(
        id: slot.slotId,
        name: slot.name,
        catalogImageKey: slot.imageKey,
        combinedRarity: slot.rarityLabel,
        isSecret: slot.isSecret,
      ),
  ];
}

CatalogFigureGalleryItem _galleryItemFromRarityFields({
  required String id,
  required String name,
  String? catalogImageKey,
  String? combinedRarity,
  required bool isSecret,
}) {
  final split = catalogFigureGallerySplitRarityOdds(combinedRarity);
  return CatalogFigureGalleryItem(
    id: id,
    name: name,
    catalogImageKey: catalogImageKey,
    rarityLabel: split.rarity,
    oddsLabel: split.odds,
    isSecret: isSecret,
  );
}
