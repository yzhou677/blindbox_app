import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:flutter/foundation.dart';

/// UI stage for the collector type reveal flow.
@immutable
sealed class CollectorTypeRevealStage {
  const CollectorTypeRevealStage();
}

/// First-time state only — no persisted reveal. Returning users bootstrap
/// directly into [CollectorTypeRevealRevealed] via the view model.
@immutable
final class CollectorTypeRevealIdle extends CollectorTypeRevealStage {
  const CollectorTypeRevealIdle({this.cachedIdentity});

  /// Legacy field; no longer set by [CollectorTypeViewModel.build].
  final CollectorTypeIdentity? cachedIdentity;
}

@immutable
final class CollectorTypeRevealAnalyzing extends CollectorTypeRevealStage {
  const CollectorTypeRevealAnalyzing();
}

@immutable
final class CollectorTypeRevealRevealed extends CollectorTypeRevealStage {
  const CollectorTypeRevealRevealed(this.identity);

  final CollectorTypeIdentity identity;
}
