import 'package:blindbox_app/features/market_intel/application/market_listing_insights.dart';
import 'package:blindbox_app/features/market_intel/application/market_snapshot_providers.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_insights_navigation_row.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_series_average_info_sheet.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_snapshot_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Sold-data price comparison shown under the listing ask price.
class MarketListingPriceDeltaLine extends ConsumerWidget {
  const MarketListingPriceDeltaLine({
    super.key,
    required this.figureId,
    required this.listingPriceUsd,
  });

  final String figureId;
  final double listingPriceUsd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnapshot = ref.watch(marketSnapshotProvider(figureId));
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return asyncSnapshot.when(
      data: (snapshot) {
        if (snapshot == null) return const SizedBox.shrink();
        final line = formatMarketListingPriceDeltaLine(
          listingPriceUsd,
          snapshot.estimatedValueUsd,
          isSeriesEstimate: snapshot.isSeriesEstimate,
          seriesId: snapshot.seriesId,
        );
        if (line == null) return const SizedBox.shrink();

        final ratio =
            (listingPriceUsd - snapshot.estimatedValueUsd) /
            snapshot.estimatedValueUsd;
        final color = ratio > 0.05
            ? scheme.tertiary
            : ratio < -0.05
                ? scheme.primary
                : scheme.onSurfaceVariant.withValues(alpha: 0.72);

        final deltaStyle = textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: color.withValues(alpha: 0.88),
        );

        if (!snapshot.isSeriesEstimate) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(line, style: deltaStyle),
          );
        }

        final isBlindBoxSeries = resolveIsBlindBoxSeries(snapshot.seriesId);

        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(line, style: deltaStyle),
              const SizedBox(width: 3),
              Semantics(
                button: true,
                label: snapshotTierBInfoSemanticsLabel(snapshot),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () => showMarketSeriesAverageInfoSheet(
                      context,
                      isBlindBoxSeries: isBlindBoxSeries,
                    ),
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          Icons.info_outline,
                          size: 18,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

/// Trust-gated entry to [MarketInsightsScreen] on [MarketDetailScreen].
///
/// Hidden when [MarketSnapshot.isSeriesEstimate] — a series average cannot
/// explain how a listing compares to market for an individual figure.
class MarketInsightsNavigationEntry extends ConsumerWidget {
  const MarketInsightsNavigationEntry({
    super.key,
    required this.figureId,
    required this.listingId,
  });

  final String figureId;
  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnapshot = ref.watch(marketSnapshotProvider(figureId));

    return asyncSnapshot.when(
      data: (snapshot) {
        if (snapshot == null || snapshot.isSeriesEstimate) {
          return const SizedBox.shrink();
        }
        return MarketInsightsNavigationRow(
          onTap: () => context.push(
            marketInsightsRoute(
              figureId: figureId,
              listingId: listingId,
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
