import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_elevation.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/home/widgets/collectible_network_image.dart';
import 'package:blindbox_app/features/market/utils/market_format.dart';
import 'package:blindbox_app/features/market/widgets/listing_market_signals.dart';
import 'package:blindbox_app/models/market_listing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Browse row — series-led, calm metadata, showcase thumb (not dense ecommerce list).
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
    final thumb = FeedRhythm.marketListingThumbnailExtent;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: FeedRhythm.marketListingFeedCardVerticalGap,
      ),
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
              padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: thumb,
                    height: thumb,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: AppRadii.matRadius,
                        color: Color.lerp(
                          scheme.surfaceContainerHighest,
                          accent,
                          isDark ? 0.1 : 0.14,
                        )!.withValues(alpha: isDark ? 0.45 : 0.55),
                        border: Border.all(
                          color: accent.withValues(alpha: isDark ? 0.12 : 0.16),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: ClipRRect(
                          borderRadius: AppRadii.insetRadius,
                          child: ColoredBox(
                            color: scheme.surface.withValues(alpha: 0.35),
                            child: CollectibleNetworkImage(
                              collectible: c,
                              heroTag: listing.marketHeroTag,
                              borderRadius: BorderRadius.zero,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.series,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: CollectibleTypography.catalogSeriesRowTitle(
                            textTheme,
                            scheme,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CollectibleTypography.figureMeta(
                            textTheme,
                            scheme,
                          ),
                        ),
                        ListingMarketSignals(listing: listing, dense: true),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              formatMarketUsd(listing.currentPriceUsd),
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _PriceChangePill(percent: listing.priceChangePercent),
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
    if (!up && !down) return const SizedBox.shrink();

    final color = up ? scheme.primary : scheme.error;

    return Text(
      formatPriceChangePercent(percent),
      style: textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: color.withValues(alpha: 0.72),
        letterSpacing: 0.02,
      ),
    );
  }
}
