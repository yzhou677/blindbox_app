import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_elevation.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/market/domain/chasers_heat_entry.dart';
import 'package:blindbox_app/features/market/presentation/collectible_market_mood_copy.dart';
import 'package:blindbox_app/features/market/widgets/market_listing_showcase_thumb.dart';
import 'package:blindbox_app/features/market/utils/market_format.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const double _kChasersCardWidth = 168;

/// Horizontal market-heat rail — identity-level chasers, not editorial trending.
class ChasersMarketSection extends StatelessWidget {
  const ChasersMarketSection({
    super.key,
    required this.entries,
    this.isLoading = false,
  });

  final List<ChasersHeatEntry> entries;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty && !isLoading) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CollectibleSectionHeader(
          title: 'Chasers',
          padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
        ),
        const SizedBox(height: FeedRhythm.sectionHeaderToRail),
        if (isLoading && entries.isEmpty)
          SizedBox(
            height: FeedRhythm.marketChasersRailHeight,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (_, _) =>
                  SizedBox(width: FeedRhythm.horizontalRailCardGap),
              itemBuilder: (context, index) => const _ChasersSkeletonCard(),
            ),
          )
        else
          SizedBox(
            height: FeedRhythm.marketChasersRailHeight,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: entries.length,
              separatorBuilder: (context, index) =>
                  SizedBox(width: FeedRhythm.horizontalRailCardGap),
              itemBuilder: (context, index) {
                return _ChasersMiniCard(entry: entries[index]);
              },
            ),
          ),
        SizedBox(height: FeedRhythm.marketChasersRailBottomClosure),
      ],
    );
  }
}

class _ChasersSkeletonCard extends StatelessWidget {
  const _ChasersSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = scheme.surfaceContainerHighest.withValues(alpha: 0.72);

    return SizedBox(
      width: _kChasersCardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: AppRadii.cardRadius,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.32),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: AppRadii.matRadius,
                    color: fill,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(height: 12, decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 6),
              Container(
                width: 88,
                height: 10,
                decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(6)),
              ),
              const SizedBox(height: 10),
              Container(
                width: 52,
                height: 14,
                decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChasersMiniCard extends StatelessWidget {
  const _ChasersMiniCard({required this.entry});

  final ChasersHeatEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listing = entry.representativeListing;
    final subtitle = CollectibleMarketMoodCopy.chaserRailSubtitle(
      ipLabel: entry.ipLabel,
    );
    final thumbExtent = _kChasersCardWidth - 24;

    return SizedBox(
      width: _kChasersCardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadii.cardRadius,
          boxShadow: CollectibleElevation.softCard(context),
        ),
        child: Material(
          color: scheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.cardRadius,
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: isDark ? 0.32 : 0.38),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/market/listing/${listing.id}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Center(
                      child: MarketListingShowcaseThumb(
                        collectible: listing.collectible,
                        extent: thumbExtent,
                        heroTag: listing.marketHeroTag,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    entry.identityLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: CollectibleTypography.catalogSeriesRowTitle(
                      textTheme,
                      scheme,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CollectibleTypography.figureMeta(textTheme, scheme),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    formatMarketUsd(listing.currentPriceUsd),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                      height: 1.1,
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
