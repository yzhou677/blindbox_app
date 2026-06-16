import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_snapshot_format.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_sheet_chrome.dart';
import 'package:flutter/material.dart';

/// Opens the Tier B listing price comparison transparency bottom sheet.
Future<void> showMarketSeriesAverageInfoSheet(
  BuildContext context, {
  required bool isBlindBoxSeries,
}) {
  return showCollectibleBottomSheet<void>(
    context: context,
    heightFraction: 0.52,
    builder: (context, scrollController) {
      return MarketSeriesAverageInfoSheet(
        scrollController: scrollController,
        isBlindBoxSeries: isBlindBoxSeries,
      );
    },
  );
}

/// Educational disclosure for Market Detail Tier B delta lines.
class MarketSeriesAverageInfoSheet extends StatelessWidget {
  const MarketSeriesAverageInfoSheet({
    super.key,
    required this.scrollController,
    required this.isBlindBoxSeries,
  });

  final ScrollController scrollController;
  final bool isBlindBoxSeries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bodyStyle = textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.88),
      height: 1.45,
    );
    final title = isBlindBoxSeries
        ? kMarketSeriesAverageInfoSheetTitle
        : kMarketMarketEstimateInfoSheetTitle;

    return CollectibleSheetInsets(
      child: CollectibleSheetScrollView(
        controller: scrollController,
        header: CollectibleSheetChrome(editorialTitle: title),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              FeedRhythm.sheetFigureRailGap,
              AppSpacing.pageHorizontal,
              AppSpacing.xl,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  isBlindBoxSeries
                      ? 'This comparison uses marketplace activity from the same '
                          'series, not sales of this specific figure.'
                      : 'This market estimate is derived from recent marketplace '
                          'activity for this product.',
                  style: bodyStyle,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  isBlindBoxSeries
                      ? 'Within a blind-box series, regular figures, popular '
                          'figures, and secrets can sell for very different prices.'
                      : 'It may not be matched to this exact collectible when '
                          'figure-specific sales are limited.',
                  style: bodyStyle,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  isBlindBoxSeries
                      ? 'Use series averages as a general reference, not as the '
                          'market value of this figure.'
                      : 'Use it as pricing context rather than an exact valuation.',
                  style: bodyStyle,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Data source: eBay marketplace activity.',
                  style: bodyStyle,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
