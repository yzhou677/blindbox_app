import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_art.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_figure_media.dart';
import 'package:blindbox_app/features/sharing/domain/share_card_payloads.dart';

ShareCardImageRef? shareCardImageRefForSeries(ShelfSeries series) {
  final local = ShelfFigureMedia.seriesCoverRef(series);
  if (local != null && local.isNotEmpty) {
    return ShareCardImageRef(kind: ShareCardImageKind.localFile, value: local);
  }

  final catalog = CollectionSeriesArt.catalogSeriesImageKey(series);
  if (catalog != null && catalog.isNotEmpty) {
    return ShareCardImageRef(
      kind: ShareCardImageKind.catalogSeries,
      value: catalog,
    );
  }

  return null;
}
