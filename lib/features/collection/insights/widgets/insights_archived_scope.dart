import 'package:flutter/material.dart';

/// Opacity applied to archived Insights cards while a re-reveal is pending.
const double collectorTypeStaleInsightsOpacity = 0.55;

/// Soft desaturation so archived cards feel inactive, not merely transparent.
const double collectorTypeStaleSaturation = 0.42;

/// Wraps **Reveal snapshot** Insights content that should read as archived
/// until Reveal again.
///
/// Do not wrap [CollectorJourneyCard] — Journey is live collection history.
class InsightsArchivedScope extends StatelessWidget {
  const InsightsArchivedScope({
    super.key,
    required this.archived,
    required this.child,
  });

  final bool archived;
  final Widget child;

  static List<double> _saturationMatrix(double s) {
    // s = 1 identity, s = 0 greyscale
    const r = 0.2126;
    const g = 0.7152;
    const b = 0.0722;
    final inv = 1 - s;
    return <double>[
      r * inv + s, g * inv, b * inv, 0, 0,
      r * inv, g * inv + s, b * inv, 0, 0,
      r * inv, g * inv, b * inv + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!archived) return child;
    return IgnorePointer(
      key: const Key('insights_archived_ignore'),
      child: Opacity(
        key: const Key('insights_archived_opacity'),
        opacity: collectorTypeStaleInsightsOpacity,
        child: ColorFiltered(
          key: const Key('insights_archived_desaturate'),
          colorFilter: ColorFilter.matrix(
            _saturationMatrix(collectorTypeStaleSaturation),
          ),
          child: child,
        ),
      ),
    );
  }
}
