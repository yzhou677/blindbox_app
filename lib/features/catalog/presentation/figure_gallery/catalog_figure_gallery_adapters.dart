import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_item.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';

List<CatalogFigureGalleryItem> catalogGalleryItemsFromCatalogSeries(
  CatalogSeries series,
) {
  return [
    for (final f in series.figures)
      CatalogFigureGalleryItem(
        id: f.templateFigureId,
        name: f.name,
        catalogImageKey: f.catalogImageKey,
        rarityLabel: f.rarity,
        isSecret: f.isSecret,
      ),
  ];
}

List<CatalogFigureGalleryItem> catalogGalleryItemsFromShelfSeries(
  ShelfSeries series,
) {
  return [
    for (final f in series.figures)
      CatalogFigureGalleryItem(
        id: f.id,
        name: f.name,
        catalogImageKey: f.imageKey,
        localImageUri: f.localImageUri,
        rarityLabel: f.displayRarity,
        isSecret: f.isSecret,
      ),
  ];
}

List<CatalogFigureGalleryItem> catalogGalleryItemsFromSeriesRelease(
  SeriesRelease release,
) {
  return [
    for (final slot in release.lineup)
      CatalogFigureGalleryItem(
        id: slot.slotId,
        name: slot.name,
        catalogImageKey: slot.imageKey,
        isSecret: slot.isSecret,
        rarityLabel: slot.isSecret ? 'Secret' : null,
      ),
  ];
}
