import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/market_intel/application/market_snapshot_providers.dart';
import 'package:blindbox_app/features/market_intel/domain/market_snapshot.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_snapshot_format.dart';
import 'package:blindbox_app/shared/widgets/app_image_shimmer.dart';
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
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
              child: asyncSnapshot.when(
                data: (snapshot) {
                  if (snapshot == null) {
                    return _MarketInsightsUnavailable(
                      scheme: scheme,
                      textTheme: textTheme,
                    );
                  }
                  return _MarketInsightsContent(snapshot: snapshot);
                },
                loading: () => const _MarketInsightsSkeleton(),
                error: (error, stackTrace) => _MarketInsightsUnavailable(
                  scheme: scheme,
                  textTheme: textTheme,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketInsightsContent extends StatelessWidget {
  const _MarketInsightsContent({required this.snapshot});

  final MarketSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final sections = <_MarketInsightsSectionData>[
      _MarketInsightsSectionData(
        label: 'Market Value',
        value: formatMarketSnapshotValue(snapshot.estimatedValueUsd),
      ),
      if (snapshot.recentSalesCount > 0)
        _MarketInsightsSectionData(
          label: 'Recent Sales',
          value: formatMarketSnapshotInsightsRecentSalesCount(snapshot),
        ),
      if (formatMarketSnapshotDiscoverPriceRangeValue(snapshot) != null)
        _MarketInsightsSectionData(
          label: 'Range',
          value: formatMarketSnapshotDiscoverPriceRangeValue(snapshot)!,
        ),
      if (formatMarketSnapshotTrendLabel(snapshot.trend) != null)
        _MarketInsightsSectionData(
          label: 'Trend',
          value: formatMarketSnapshotTrendLabel(snapshot.trend)!,
        ),
      _MarketInsightsSectionData(
        label: 'Updated',
        value: formatMarketSnapshotInsightsUpdatedValue(snapshot.computedAt),
      ),
      const _MarketInsightsSectionData(
        label: 'Data Source',
        value: kMarketInsightsDataSourceValue,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (snapshot.isSeriesEstimate) ...[
          Text(
            kMarketSnapshotDiscoverSeriesFallbackLabel,
            style: textTheme.labelMedium?.copyWith(
              color: scheme.tertiary.withValues(alpha: 0.92),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
        ],
        for (var i = 0; i < sections.length; i++) ...[
          _MarketInsightsSectionRow(section: sections[i]),
          if (i < sections.length - 1) const SizedBox(height: 18),
        ],
        const SizedBox(height: 28),
        Text(
          kMarketInsightsScreenFooter,
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _MarketInsightsSectionData {
  const _MarketInsightsSectionData({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _MarketInsightsSectionRow extends StatelessWidget {
  const _MarketInsightsSectionRow({required this.section});

  final _MarketInsightsSectionData section;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.label,
          style: CollectibleTypography.figureMeta(textTheme, scheme).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          section.value,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _MarketInsightsSkeleton extends StatelessWidget {
  const _MarketInsightsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 4; i++) ...[
          SizedBox(
            width: 96,
            height: 12,
            child: AppImageShimmer(borderRadius: BorderRadius.circular(6)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            height: 24,
            child: AppImageShimmer(borderRadius: BorderRadius.circular(8)),
          ),
          if (i < 3) const SizedBox(height: 18),
        ],
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
