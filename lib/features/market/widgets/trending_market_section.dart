import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_elevation.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/home/widgets/collectible_network_image.dart';
import 'package:blindbox_app/features/market/utils/market_format.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const double _kTrendingCardWidth = 168;

/// Horizontal discovery rail — image showcase, quiet price read.
class TrendingMarketSection extends StatelessWidget {
  const TrendingMarketSection({super.key, required this.items});

  final List<MarketListing> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CollectibleSectionHeader(
          title: 'Trending',
          padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
        ),
        const SizedBox(height: FeedRhythm.sectionHeaderToRail),
        SizedBox(
          height: FeedRhythm.marketTrendingRailHeight,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) =>
                SizedBox(width: FeedRhythm.horizontalRailCardGap),
            itemBuilder: (context, index) {
              return _TrendingMiniCard(listing: items[index]);
            },
          ),
        ),
        SizedBox(height: FeedRhythm.marketTrendingRailBottomClosure),
      ],
    );
  }
}

class _TrendingMiniCard extends StatelessWidget {
  const _TrendingMiniCard({required this.listing});

  final MarketListing listing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final c = listing.collectible;
    final accent = c.shelfAccent ?? scheme.tertiaryContainer;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: _kTrendingCardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadii.cardRadius,
          boxShadow: CollectibleElevation.softCard(context),
        ),
        child: Material(
          color: Color.lerp(
            scheme.surfaceContainerLow,
            accent,
            isDark ? 0.06 : 0.1,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.cardRadius,
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.36),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/market/listing/${listing.id}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: AppRadii.matRadius,
                        color: scheme.surface.withValues(
                          alpha: isDark ? 0.28 : 0.62,
                        ),
                        border: Border.all(
                          color: accent.withValues(alpha: isDark ? 0.1 : 0.14),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: ClipRRect(
                          borderRadius: AppRadii.insetRadius,
                          child: ColoredBox(
                            color: scheme.surface.withValues(alpha: 0.2),
                            child: CollectibleNetworkImage(
                              collectible: c,
                              borderRadius: BorderRadius.zero,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    c.series,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CollectibleTypography.catalogSeriesRowTitle(
                      textTheme,
                      scheme,
                    ).copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CollectibleTypography.figureMeta(textTheme, scheme),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatMarketUsd(listing.currentPriceUsd),
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
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
