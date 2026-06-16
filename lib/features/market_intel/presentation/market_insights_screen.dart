import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/market/application/market_listing_lookup.dart';
import 'package:blindbox_app/features/market_intel/application/market_insights_figure_context.dart';
import 'package:blindbox_app/features/market_intel/application/market_snapshot_providers.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_snapshot_format.dart';
import 'package:blindbox_app/shared/widgets/app_image_shimmer.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MarketInsightsScreen extends ConsumerWidget {
  const MarketInsightsScreen({
    super.key,
    required this.figureId,
    required this.listingId,
  });

  final String figureId;
  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final listing = ref.watch(marketListingByIdProvider(listingId));
    final figureContext = resolveMarketInsightsFigureContext(
      figureId: figureId,
      listing: listing,
    );
    final asyncSnapshot = ref.watch(marketSnapshotProvider(figureId));

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            toolbarHeight: FeedRhythm.mainTabAppBarToolbarHeight,
            titleSpacing: AppSpacing.pageHorizontal,
            backgroundColor: scheme.surface.withValues(alpha: 0.94),
            surfaceTintColor: scheme.surfaceTint.withValues(alpha: 0.45),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            title: Text(
              kMarketInsightsScreenTitle,
              style: textTheme.titleLarge,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MarketInsightsFigureHeader(context: figureContext),
                  const SizedBox(height: 18),
                  asyncSnapshot.when(
                    data: (snapshot) {
                      if (snapshot == null) {
                        return _MarketInsightsUnavailable(
                          scheme: scheme,
                          textTheme: textTheme,
                        );
                      }
                      return _MarketInsightsContent(
                        snapshot: snapshot,
                        listingPriceUsd: listing?.currentPriceUsd,
                      );
                    },
                    loading: () => const _MarketInsightsSkeleton(),
                    error: (error, stackTrace) => _MarketInsightsUnavailable(
                      scheme: scheme,
                      textTheme: textTheme,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketInsightsFigureHeader extends StatelessWidget {
  const _MarketInsightsFigureHeader({required this.context});

  final MarketInsightsFigureContext context;

  @override
  Widget build(BuildContext buildContext) {
    final scheme = Theme.of(buildContext).colorScheme;
    final textTheme = Theme.of(buildContext).textTheme;
    const thumbExtent = 72.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: AppRadii.insetRadius,
          child: SizedBox(
            width: thumbExtent,
            height: thumbExtent,
            child: context.imageKey != null
                ? CatalogImageFromKey(
                    imageKey: context.imageKey!,
                    name: context.figureName,
                    seedKey: context.imageKey!,
                    displayMode: CatalogImageDisplayMode.figureThumb,
                    borderRadius: BorderRadius.zero,
                  )
                : CollectibleFigurePlaceholder(
                    name: context.figureName,
                    seedKey: context.figureName,
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.figureName,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                if (context.seriesName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    context.seriesName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: CollectibleTypography.figureMeta(textTheme, scheme),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MarketInsightsContent extends StatelessWidget {
  const _MarketInsightsContent({
    required this.snapshot,
    required this.listingPriceUsd,
  });

  final MarketSnapshot snapshot;
  final double? listingPriceUsd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final activityLine = _formatMarketInsightsActivityLine(snapshot);
    final rangeLine = formatMarketSnapshotInsightsRangeLine(snapshot);
    final updatedLine =
        formatMarketSnapshotInsightsUpdatedMetadataLine(snapshot.computedAt);
    final metaStyle = textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
      height: 1.35,
    );
    final activityStyle = textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.84),
      height: 1.3,
    );
    final labelStyle = CollectibleTypography.figureMeta(textTheme, scheme)
        .copyWith(fontWeight: FontWeight.w600);
    final valueStyle = textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.05,
      letterSpacing: -0.15,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (snapshot.isSeriesEstimate) ...[
          Text(
            snapshotTierBBannerLabel(snapshot),
            style: textTheme.labelMedium?.copyWith(
              color: scheme.tertiary.withValues(alpha: 0.92),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
        ],
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: AppRadii.insetRadius,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            snapshotTierValueLabel(snapshot),
                            style: labelStyle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatMarketSnapshotValue(snapshot.estimatedValueUsd),
                            style: valueStyle,
                          ),
                        ],
                      ),
                    ),
                    if (listingPriceUsd != null) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Current Listing', style: labelStyle),
                            const SizedBox(height: 4),
                            Text(
                              formatMarketSnapshotValue(listingPriceUsd!),
                              style: valueStyle,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (listingPriceUsd != null) ...[
                  const SizedBox(height: 12),
                  _MarketInsightsPurchaseDeltaLine(
                    listingPriceUsd: listingPriceUsd!,
                    estimatedValueUsd: snapshot.estimatedValueUsd,
                    isSeriesEstimate: snapshot.isSeriesEstimate,
                    seriesId: snapshot.seriesId,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (activityLine != null) ...[
          const SizedBox(height: 14),
          Text(activityLine, style: activityStyle),
        ],
        if (rangeLine != null) ...[
          const SizedBox(height: 10),
          Text(rangeLine, style: metaStyle),
        ],
        const SizedBox(height: 6),
        Text(updatedLine, style: metaStyle),
        const SizedBox(height: 20),
        Text(
          'Data Source',
          style: CollectibleTypography.figureMeta(textTheme, scheme).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          kMarketInsightsDataSourceValue,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          kMarketInsightsScreenFooter,
          style: metaStyle,
        ),
      ],
    );
  }
}

class _MarketInsightsPurchaseDeltaLine extends StatelessWidget {
  const _MarketInsightsPurchaseDeltaLine({
    required this.listingPriceUsd,
    required this.estimatedValueUsd,
    required this.isSeriesEstimate,
    required this.seriesId,
  });

  final double listingPriceUsd;
  final double estimatedValueUsd;
  final bool isSeriesEstimate;
  final String seriesId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final line = formatMarketListingPriceDeltaLine(
      listingPriceUsd,
      estimatedValueUsd,
      isSeriesEstimate: isSeriesEstimate,
      seriesId: seriesId,
    );
    if (line == null) return const SizedBox.shrink();

    final ratio = (listingPriceUsd - estimatedValueUsd) / estimatedValueUsd;
    final color = ratio > 0.05
        ? scheme.tertiary
        : ratio < -0.05
            ? scheme.primary
            : scheme.onSurfaceVariant.withValues(alpha: 0.72);

    return Text(
      line,
      style: textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: color.withValues(alpha: 0.92),
      ),
    );
  }
}

String? _formatMarketInsightsActivityLine(MarketSnapshot snapshot) {
  final sales = formatMarketSnapshotInsightsActivitySalesLine(snapshot);
  final trend = formatMarketSnapshotTrendLabel(snapshot.trend);
  if (sales == null && trend == null) return null;
  if (sales != null && trend != null) return '$sales · $trend';
  return sales ?? trend;
}

class _MarketInsightsSkeleton extends StatelessWidget {
  const _MarketInsightsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 108,
          child: AppImageShimmer(borderRadius: AppRadii.insetRadius),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: 180,
          height: 14,
          child: AppImageShimmer(borderRadius: BorderRadius.circular(6)),
        ),
      ],
    );
  }
}

class _MarketInsightsUnavailable extends StatelessWidget {
  const _MarketInsightsUnavailable({
    required this.scheme,
    required this.textTheme,
  });

  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      kMarketDetailInsightsUnavailable,
      style: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
        height: 1.35,
      ),
    );
  }
}
