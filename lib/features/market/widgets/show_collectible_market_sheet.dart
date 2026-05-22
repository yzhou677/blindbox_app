import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/market/application/collectible_market_display_resolver.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_snapshot.dart';
import 'package:blindbox_app/features/market/presentation/collectible_market_mood_copy.dart';
import 'package:blindbox_app/features/market/widgets/market_listing_card.dart';
import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_providers.dart';
import 'package:blindbox_app/features/collectible_relationship/widgets/collectible_relationship_line.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showCollectibleMarketSheet({
  required BuildContext context,
  required CollectibleMarketSnapshot snapshot,
}) {
  final display = resolveCollectibleMarketDisplay(snapshot);
  final listings = listingsForSnapshot(snapshot);

  return showCollectibleBottomSheet<void>(
    context: context,
    heightFraction: FeedRhythm.sheetOpenScreenFraction,
    builder: (ctx, scrollController) {
      return Consumer(
        builder: (ctx, ref, _) {
      final scheme = Theme.of(ctx).colorScheme;
      final textTheme = Theme.of(ctx).textTheme;
      final relationshipLine = ref.watch(
        relationshipHintForMarketSnapshotProvider(snapshot.identity.snapshotId),
      );

      return CollectibleSheetInsets(
        child: CustomScrollView(
          controller: scrollController,
          physics: collectibleSheetScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    display.title,
                    style: CollectibleTypography.catalogSeriesRowTitle(
                      textTheme,
                      scheme,
                    ),
                  ),
                  if (display.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      display.subtitle,
                      style: CollectibleTypography.figureMeta(textTheme, scheme),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    CollectibleMarketMoodCopy.subtitle(snapshot),
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CollectibleMarketMoodCopy.sightingsLabel(snapshot.listingCount),
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                    ),
                  ),
                  if (relationshipLine != null &&
                      relationshipLine.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    CollectibleRelationshipLine(text: relationshipLine),
                  ],
                  const SizedBox(height: FeedRhythm.blockGapMedium),
                ],
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final listing = listings[index];
                  return MarketListingCard(listing: listing);
                },
                childCount: listings.length,
              ),
            ),
          ],
        ),
      );
        },
      );
    },
  );
}
