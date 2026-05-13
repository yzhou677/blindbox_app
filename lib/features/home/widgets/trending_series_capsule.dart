import 'package:blindbox_app/core/theme/collectible_shelf_shadow.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/models/toy_series_highlight.dart';
import 'package:flutter/material.dart';

const double kTrendingSeriesCapsuleWidth = 164;
const double kTrendingSeriesCapsuleHeight = 128;

/// Compact universe capsule — distinct from [LatestDropCard] (no hero SKU photography).
class TrendingSeriesCapsule extends StatelessWidget {
  const TrendingSeriesCapsule({super.key, required this.series});

  final ToySeriesHighlight series;

  String _metaLine() {
    final count = '${series.figureCount} figures';
    final tag = series.tagline;
    if (tag == null || tag.isEmpty) return count;
    return '$count · $tag';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final radius = CollectibleShape.shellRadius;

    return SizedBox(
      width: kTrendingSeriesCapsuleWidth,
      height: kTrendingSeriesCapsuleHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: CollectibleShelfShadow.productShell(context, accent: series.accent),
        ),
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              // Series hubs / filters ship with catalog integration.
            },
            splashColor: scheme.primary.withValues(alpha: 0.06),
            highlightColor: scheme.primary.withValues(alpha: 0.04),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(series.accent, scheme.surface, 0.12)!,
                    scheme.surfaceContainerLow.withValues(alpha: isDark ? 0.92 : 1),
                  ],
                ),
                border: Border.all(
                  color: series.accent.withValues(alpha: isDark ? 0.35 : 0.55),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: radius.topLeft,
                          bottomLeft: radius.bottomLeft,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            series.accent.withValues(alpha: 0.95),
                            Color.lerp(series.accent, scheme.primary, 0.15)!
                                .withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 11, 11, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (series.brand != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer.withValues(alpha: 0.42),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              series.brand!,
                              style: textTheme.labelSmall?.copyWith(
                                letterSpacing: 0.12,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSecondaryContainer.withValues(alpha: 0.82),
                                height: 1.12,
                              ),
                            ),
                          ),
                        if (series.brand != null) const SizedBox(height: 7),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              series.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.14,
                                height: 1.16,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          _metaLine(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.04,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
