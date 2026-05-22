import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';

/// Single UI → notifier entry for adding a catalog template to the shelf.
///
/// Commits immediately from in-memory [template] (figure [CatalogFigure.catalogImageKey]
/// is enough for shelf tiles; no Storage probe before state updates).
void commitCatalogSeriesToShelf(
  CollectionNotifier notifier,
  CatalogSeries template,
) {
  notifier.addSeriesFromTemplate(template);
}
