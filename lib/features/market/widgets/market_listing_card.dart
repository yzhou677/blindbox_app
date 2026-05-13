import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/collectible_shelf_shadow.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/home/widgets/collectible_network_image.dart';
import 'package:blindbox_app/features/market/utils/market_format.dart';
import 'package:blindbox_app/features/market/widgets/listing_market_signals.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Full-width listing tile — imagery first, soft market cues (StockX-adjacent, not a terminal).
class MarketListingCard extends StatelessWidget {
  const MarketListingCard({super.key, required this.listing});

  final MarketListing listing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final c = listing.collectible;
    final accent = c.shelfAccent ?? scheme.tertiaryContainer;
    final isDark = theme.brightness == Brightness.dark;
    final outerRadius = CollectibleShape.shellRadius;

    return Padding(
      padding: const EdgeInsets.only(bottom: FeedRhythm.listingCardVerticalGap),
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
              color: accent.withValues(alpha: isDark ? 0.2 : 0.34),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/market/listing/${listing.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1.12,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: CollectibleShape.matRadius,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.lerp(scheme.surface, accent, 0.34)!
                                .withValues(alpha: isDark ? 0.38 : 0.58),
                            accent.withValues(alpha: 0.34),
                            scheme.surface.withValues(alpha: 0.08),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                        border: Border.all(
                          color: accent.withValues(alpha: isDark ? 0.12 : 0.2),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: ClipRRect(
                          borderRadius: CollectibleShape.insetRadius,
                          child: ColoredBox(
                            color: scheme.surface.withValues(alpha: 0.58),
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
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.18,
                          height: 1.2,
                        ),
                      ),
                      ListingMarketSignals(listing: listing),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatMarketUsd(listing.currentPriceUsd),
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.45,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _PriceChangePill(percent: listing.priceChangePercent),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.layers_outlined,
                            size: 18,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${listing.listingCount} listings',
                            style: textTheme.labelLarge?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '·',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              c.series,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: up ? 0.14 : down ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        formatPriceChangePercent(percent),
        style: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: color.withValues(alpha: 0.92),
          letterSpacing: 0.12,
        ),
      ),
    );
  }
}
