import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_elevation.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/market/application/collectible_market_display_resolver.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_snapshot.dart';
import 'package:blindbox_app/features/market/presentation/collectible_market_mood_copy.dart';
import 'package:blindbox_app/features/market/widgets/market_listing_showcase_thumb.dart';
import 'package:blindbox_app/features/market/utils/market_format.dart';
import 'package:blindbox_app/features/market/widgets/collectible_market_signals.dart';
import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_providers.dart';
import 'package:blindbox_app/features/collectible_relationship/widgets/collectible_relationship_line.dart';
import 'package:blindbox_app/features/market/widgets/show_collectible_market_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Collectible-centered browse row — groups market sightings calmly.
class CollectibleMarketCard extends ConsumerWidget {
  const CollectibleMarketCard({
    super.key,
    required this.snapshot,
    this.onOpen,
  });

  final CollectibleMarketSnapshot snapshot;

  /// Optional hook before opening the market sheet (e.g. record search history).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final display = resolveCollectibleMarketDisplay(snapshot);
    final rep = representativeListing(snapshot);
    final isDark = theme.brightness == Brightness.dark;
    final thumb = FeedRhythm.marketListingThumbnailExtent;
    final relationshipLine = ref.watch(
      relationshipHintForMarketSnapshotProvider(snapshot.identity.snapshotId),
    );

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
            onTap: rep == null
                ? null
                : () {
                    onOpen?.call();
                    showCollectibleMarketSheet(
                      context: context,
                      snapshot: snapshot,
                    );
                  },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rep != null)
                    MarketListingShowcaseThumb(
                      collectible: rep.collectible,
                      extent: thumb,
                      heroTag: 'collectible-market-${snapshot.identity.snapshotId}',
                    ),
                  if (rep != null) const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          display.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: CollectibleTypography.catalogSeriesRowTitle(
                            textTheme,
                            scheme,
                          ),
                        ),
                        if (display.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            display.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CollectibleTypography.figureMeta(
                              textTheme,
                              scheme,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          CollectibleMarketMoodCopy.subtitle(snapshot),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                            height: 1.25,
                          ),
                        ),
                        CollectibleMarketSignals(snapshot: snapshot),
                        if (relationshipLine != null &&
                            relationshipLine.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          CollectibleRelationshipLine(text: relationshipLine),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          _priceLabel(),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                            height: 1.1,
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

  String _priceLabel() {
    final range = snapshot.observedPriceRange;
    if (snapshot.listingCount > 1 && !range.isSinglePrice) {
      return '${formatMarketUsd(range.minUsd)}–${formatMarketUsd(range.maxUsd)}';
    }
    return formatMarketUsd(range.minUsd);
  }
}
