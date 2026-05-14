import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/home/widgets/collectible_network_image.dart';
import 'package:blindbox_app/features/market/utils/market_format.dart';
import 'package:blindbox_app/features/market/widgets/listing_market_signals.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Browse feed row — compact thumbnail + metadata (lighter than hero “shell” tiles).
class MarketListingCard extends StatelessWidget {
  const MarketListingCard({super.key, required this.listing});

  final MarketListing listing;

  static const double _thumbRadius = 12;
  static const double _cardRadius = 14;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final c = listing.collectible;
    final accent = c.shelfAccent ?? scheme.tertiaryContainer;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: FeedRhythm.marketListingFeedCardVerticalGap),
      child: Material(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.42 : 0.55),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/market/listing/${listing.id}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: FeedRhythm.marketListingThumbnailExtent,
                  height: FeedRhythm.marketListingThumbnailExtent,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_thumbRadius),
                      color: Color.lerp(
                        scheme.surfaceContainerHighest,
                        accent,
                        isDark ? 0.12 : 0.18,
                      )!.withValues(alpha: isDark ? 0.55 : 0.72),
                      border: Border.all(
                        color: accent.withValues(alpha: isDark ? 0.14 : 0.22),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(_thumbRadius - 4),
                        child: ColoredBox(
                          color: scheme.surface.withValues(alpha: 0.5),
                          child: CollectibleNetworkImage(
                            collectible: c,
                            heroTag: listing.marketHeroTag,
                            borderRadius: CollectibleShape.insetRadius,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.12,
                          height: 1.22,
                        ),
                      ),
                      ListingMarketSignals(listing: listing, dense: true),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatMarketUsd(listing.currentPriceUsd),
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.35,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _PriceChangePill(percent: listing.priceChangePercent),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.layers_outlined,
                            size: 16,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${listing.listingCount} listings',
                            style: textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.86),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '·',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.series,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
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

class _PriceChangePill extends StatelessWidget {
  const _PriceChangePill({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final up = percent > 0;
    final down = percent < 0;
    final color = up
        ? scheme.primary
        : down
            ? scheme.error
            : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: up ? 0.12 : down ? 0.1 : 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        formatPriceChangePercent(percent),
        style: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: color.withValues(alpha: 0.9),
          letterSpacing: 0.08,
        ),
      ),
    );
  }
}
