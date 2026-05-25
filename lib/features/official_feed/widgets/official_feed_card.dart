import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_shelf_shadow.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_relative_time.dart';
import 'package:blindbox_app/features/official_feed/utils/open_official_feed_url.dart';
import 'package:blindbox_app/features/official_feed/widgets/official_feed_cover_image.dart';
import 'package:flutter/material.dart';

/// Editorial official drop card — image-first, opens external URL.
class OfficialFeedCard extends StatelessWidget {
  const OfficialFeedCard({super.key, required this.item});

  final OfficialFeedItem item;

  static const double _titleFontSize = 16;
  static const double _titleLineHeight = 1.24;
  static const int _titleMaxLines = 2;
  static const double _titleBlockHeight =
      _titleFontSize * _titleLineHeight * _titleMaxLines;
  static const double _metaRowHeight = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final shellAccent = scheme.secondary.withValues(alpha: isDark ? 0.2 : 0.14);

    return RepaintBoundary(
      child: SizedBox(
        width: FeedRhythm.homeOfficialFeedCardWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadii.shellRadius,
            boxShadow: CollectibleShelfShadow.productShell(
              context,
              accent: shellAccent,
            ),
          ),
          child: Material(
            color: scheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadii.shellRadius,
              side: BorderSide(
                color: scheme.outlineVariant.withValues(
                  alpha: isDark ? 0.18 : 0.28,
                ),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Semantics(
              button: true,
              label: '${item.title}. Opens in browser.',
              child: InkWell(
                onTap: () => openOfficialFeedUrl(context, item.officialUrl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      children: [
                        OfficialFeedCoverImage(imageUrl: item.imageUrl),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  scheme.scrim.withValues(alpha: 0.04),
                                  Colors.transparent,
                                  scheme.scrim.withValues(
                                    alpha: isDark ? 0.34 : 0.22,
                                  ),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          top: 10,
                          child: _SourceChip(label: item.sourceLabel),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: _titleBlockHeight,
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                item.title,
                                maxLines: _titleMaxLines,
                                overflow: TextOverflow.ellipsis,
                                style: CollectibleTypography.seriesHeroTitle(
                                  textTheme,
                                  scheme,
                                ).copyWith(
                                  fontSize: _titleFontSize,
                                  height: _titleLineHeight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: _metaRowHeight,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  formatOfficialFeedRelativeTime(
                                    item.publishedAt,
                                  ),
                                  style: CollectibleTypography.figureMeta(
                                    textTheme,
                                    scheme,
                                  ).copyWith(
                                    letterSpacing: 0.04,
                                    color: scheme.onSurfaceVariant.withValues(
                                      alpha: 0.42,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.north_east_rounded,
                                  size: 15,
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.38,
                                  ),
                                ),
                              ],
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
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(
          alpha: isDark ? 0.78 : 0.9,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.28 : 0.32),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.05,
            color: scheme.onSurface.withValues(alpha: 0.82),
          ),
        ),
      ),
    );
  }
}
