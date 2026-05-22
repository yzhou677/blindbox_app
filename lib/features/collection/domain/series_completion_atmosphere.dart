import 'package:flutter/foundation.dart';

/// Per-series completion atmosphere hints for calm UI treatment.
@immutable
class SeriesCompletionAtmosphere {
  const SeriesCompletionAtmosphere({
    this.nearComplete = false,
    this.missingSecret = false,
    this.complete = false,
    this.rareLineup = false,
    this.harmony = false,
  });

  final bool nearComplete;
  final bool missingSecret;
  final bool complete;
  final bool rareLineup;
  final bool harmony;

  bool get hasAccent =>
      nearComplete || missingSecret || complete || rareLineup || harmony;
}
