import 'package:blindbox_app/features/collection/application/share_payload_builders/share_card_image_ref_builder.dart';
import 'package:blindbox_app/features/collection/application/share_payload_builders/share_card_series_label.dart';
import 'package:blindbox_app/features/collection/application/share_payload_builders/shelf_share_featured_series_selector.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/sharing/domain/share_card_payloads.dart';

ShelfSharePayload buildShelfSharePayload({
  required CollectionSnapshot snapshot,
  CollectorTypeIdentity? collectorTypeIdentity,
  DateTime? generatedAt,
}) {
  final aggregate = aggregateShelfCompletion(snapshot);
  final featured = selectShelfShareFeaturedSeries(snapshot)
      .map((series) => _shelfShareSeriesItem(series, snapshot.figureStates))
      .whereType<ShelfShareSeriesItem>()
      .toList(growable: false);

  return ShelfSharePayload(
    label: 'SHELFY SHELF CARD · CURRENT',
    collectorTypeName: collectorTypeIdentity?.healed().archetype.displayName,
    ownedFigureCount: snapshot.totalOwnedFigures,
    trackedSeriesCount: snapshot.trackedSeriesCount,
    completedSeriesCount: aggregate.completedSeriesCount,
    masterCompleteSeriesCount: aggregate.masterCompleteSeriesCount,
    overallRegularProgress: aggregate.regularCompletionPercent,
    featuredSeries: featured,
    generatedAt: generatedAt ?? DateTime.now(),
  );
}

ShelfShareSeriesItem? _shelfShareSeriesItem(
  ShelfSeries series,
  Map<String, TrackedFigure> states,
) {
  final image = shareCardImageRefForSeries(series);
  if (image == null) return null;
  final resolution = resolveSeriesCompletion(series, states);
  return ShelfShareSeriesItem(
    seriesId: series.id,
    seriesName: shareCardSeriesLabel(series.name),
    ipName: shelfSeriesIpLabel(series),
    image: image,
    regularProgress: resolution.progressRatio,
    isCompleted: resolution.isCompleted,
    isMasterComplete: resolution.isMasterComplete,
  );
}
