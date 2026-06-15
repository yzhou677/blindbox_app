import 'package:blindbox_app/features/market_intel/application/market_snapshot_providers.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_snapshot_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            line,
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.88),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
