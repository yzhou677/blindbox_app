import 'package:blindbox_app/features/collection/application/share_payload_builders/share_card_image_ref_builder.dart';
import 'package:blindbox_app/features/collection/application/share_payload_builders/share_card_series_label.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/sharing/domain/share_card_payloads.dart';

MasterCompleteSharePayload? buildMasterCompleteSharePayload({
  required ShelfSeries series,
  required Map<String, TrackedFigure> figureStates,
}) {
  final resolution = resolveSeriesCompletion(series, figureStates);
  if (!resolution.isMasterComplete) return null;

  final image = shareCardImageRefForSeries(series);
  if (image == null) return null;

  return MasterCompleteSharePayload(
    label: 'SHELFY CHASE CARD · MASTER',
    seriesName: shareCardSeriesLabel(series.name, uppercase: true),
    image: image,
    metadata:
        'REGULAR ${resolution.regularOwnedCount}/${resolution.regularSlotCount} · SECRET ${resolution.secretOwnedCount}/${resolution.secretSlotCount}',
    regularOwned: resolution.regularOwnedCount,
    regularTotal: resolution.regularSlotCount,
    secretOwned: resolution.secretOwnedCount,
    secretTotal: resolution.secretSlotCount,
  );
}
