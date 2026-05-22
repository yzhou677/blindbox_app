import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/market/application/collectible_market_display_resolver.dart';
import 'package:blindbox_app/features/market/domain/collectible_market_snapshot.dart';
import 'package:blindbox_app/features/market/presentation/collectible_market_mood_copy.dart';
import 'package:blindbox_app/features/market/widgets/collectible_market_signals.dart';
import 'package:blindbox_app/features/market/widgets/market_listing_card.dart';
import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_providers.dart';
import 'package:blindbox_app/features/collectible_relationship/widgets/collectible_relationship_line.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_sheet_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showCollectibleMarketSheet({
  required BuildContext context,
  required CollectibleMarketSnapshot snapshot,
}) {
  final display = resolveCollectibleMarketDisplay(snapshot);
  final listings = listingsForSnapshot(snapshot);
  final rep = representativeListing(snapshot);
  final openFraction = listings.length <= 2
      ? FeedRhythm.sheetPreviewOpenScreenFraction
      : FeedRhythm.sheetOpenScreenFraction;

  return showCollectibleBottomSheet<void>(
    context: context,
    heightFraction: openFraction,
    builder: (ctx, scrollController) {
      return Consumer(
        builder: (ctx, ref, _) {
          final scheme = Theme.of(ctx).colorScheme;
          final textTheme = Theme.of(ctx).textTheme;
          final relationshipLine = ref.watch(
            relationshipHintForMarketSnapshotProvider(
              snapshot.identity.snapshotId,
            ),
          );
          final c = rep?.collectible;
          final trailingMeta = [
            CollectibleMarketMoodCopy.snapshotPriceLabel(snapshot),
            CollectibleMarketMoodCopy.sightingsLabel(snapshot.listingCount),
          ].join(' · ');

          return CollectibleSheetInsets(
            child: CustomScrollView(
              controller: scrollController,
              physics: collectibleSheetScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CollectibleSheetChrome(
                        seriesTitle: display.title,
                        brand: c?.brand ?? '',
                        ipLine: c?.ipLine?.trim() ?? '',
                        trailingMeta: trailingMeta,
                      ),
                      const SizedBox(height: FeedRhythm.sheetEditorialBlockGap),
                      Text(
                        CollectibleMarketMoodCopy.subtitle(snapshot),
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                          height: 1.35,
                        ),
                      ),
                      if (display.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          display.subtitle,
                          style: CollectibleTypography.figureMeta(
                            textTheme,
                            scheme,
                          ),
                        ),
                      ],
                      CollectibleMarketSignals(snapshot: snapshot),
                      if (relationshipLine != null &&
                          relationshipLine.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        CollectibleRelationshipLine(text: relationshipLine),
                      ],
                      const SizedBox(height: FeedRhythm.sheetFigureRailGap),
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
