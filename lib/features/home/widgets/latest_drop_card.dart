import 'package:blindbox_app/core/theme/collectible_shelf_shadow.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/features/home/widgets/save_series_release_button.dart';
import 'package:blindbox_app/features/home/widgets/series_release_cover_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Series launch tile — hero figure art, series title, figure count (no repeated month).
const double _kCardWidth = 252;
const double _kImageAspect = 1.02;

class LatestDropCard extends StatelessWidget {
  const LatestDropCard({super.key, required this.release});

  final SeriesRelease release;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final outerRadius = CollectibleShape.shellRadius;
    final hero = release.heroCollectible;
    final accent = hero.shelfAccent ?? scheme.tertiaryContainer;

    return SizedBox(
      width: _kCardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: outerRadius,
          boxShadow: CollectibleShelfShadow.productShell(context, accent: accent),
        ),
        child: Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: outerRadius,
            side: BorderSide(
              color: accent.withValues(alpha: theme.brightness == Brightness.dark ? 0.16 : 0.34),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/home/detail/${release.dropId}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: _kImageAspect,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: CollectibleShape.matRadius,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.lerp(scheme.surface, accent, 0.38)!
                                .withValues(alpha: theme.brightness == Brightness.dark ? 0.32 : 0.58),
                            accent.withValues(alpha: theme.brightness == Brightness.dark ? 0.32 : 0.4),
                            scheme.surface.withValues(alpha: theme.brightness == Brightness.dark ? 0.18 : 0.12),
                          ],
                          stops: const [0.0, 0.42, 1.0],
                        ),
                        border: Border.all(
                          color: accent.withValues(alpha: theme.brightness == Brightness.dark ? 0.11 : 0.2),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: ClipRRect(
                          borderRadius: CollectibleShape.insetRadius,
                          child: ColoredBox(
                            color: scheme.surface.withValues(
                              alpha: theme.brightness == Brightness.dark ? 0.82 : 0.72,
                            ),
                            child: SeriesReleaseCoverImage(
                              release: release,
                              heroTag: SeriesReleaseCoverImage.heroTagFor(release),
                              borderRadius: CollectibleShape.insetRadius,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        release.seriesName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.18,
                          height: 1.15,
                          color: scheme.onSurface.withValues(alpha: 0.94),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hero.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.02,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '${release.lineup.length} figures',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.68),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          SaveSeriesReleaseButton(release: release),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
