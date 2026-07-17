import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_shelf_shadow.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/features/home/widgets/save_series_release_button.dart';
import 'package:blindbox_app/features/home/widgets/series_release_cover_image.dart';
import 'package:blindbox_app/shared/widgets/series_hero_meta_block.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Series launch showcase tile — art-first, series title, quiet IP/brand.
class LatestDropCard extends StatelessWidget {
  const LatestDropCard({super.key, required this.release});

  final SeriesRelease release;

  static const double _imageAspect = 1.05;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final hero = release.heroCollectible;
    final accent = hero.shelfAccent ?? scheme.tertiaryContainer;

    return SizedBox(
      width: FeedRhythm.homeSeriesRailCardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadii.shellRadius,
          boxShadow: CollectibleShelfShadow.productShell(
            context,
            accent: accent,
          ),
        ),
        child: Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.shellRadius,
            side: BorderSide(
              color: accent.withValues(alpha: isDark ? 0.16 : 0.3),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              InkWell(
                onTap: () => context.push('/home/detail/${release.dropId}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: _imageAspect,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: AppRadii.matRadius,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color.lerp(
                                  scheme.surface,
                                  accent,
                                  0.32,
                                )!.withValues(alpha: isDark ? 0.28 : 0.5),
                                accent.withValues(
                                  alpha: isDark ? 0.26 : 0.34,
                                ),
                                scheme.surface.withValues(alpha: 0.08),
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                            border: Border.all(
                              color: accent.withValues(
                                alpha: isDark ? 0.1 : 0.18,
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: AppRadii.matRadius,
                            child: SeriesReleaseCoverImage(
                              release: release,
                              heroTag: SeriesReleaseCoverImage.heroTagFor(
                                release,
                              ),
                              borderRadius: AppRadii.matRadius,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 12, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            release.seriesName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: CollectibleTypography.seriesHeroTitle(
                              textTheme,
                              scheme,
                            ).copyWith(fontSize: 19),
                          ),
                          SeriesHeroMetaBlock(
                            brand: release.brand,
                            ipLine: release.ipLine ?? release.brand,
                            trailingMeta: release.lineup.length == 1
                                ? '1 figure'
                                : '${release.lineup.length} figures',
                            density: SeriesHeroMetaDensity.compact,
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: SaveSeriesReleaseButton(release: release),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: SeriesReleaseWishlistButton(release: release),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
