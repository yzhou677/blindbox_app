import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_sheet_chrome.dart';
import 'package:flutter/material.dart';

/// Semantics label for the Market Detail series-average delta info affordance.
const String kMarketSeriesAverageInfoSemanticsLabel =
    'About series average pricing';

/// Bottom sheet title for Tier B listing price comparison disclosure.
const String kMarketSeriesAverageInfoSheetTitle = 'About series average pricing';

/// Opens the series-average pricing transparency bottom sheet.
Future<void> showMarketSeriesAverageInfoSheet(BuildContext context) {
  return showCollectibleBottomSheet<void>(
    context: context,
    heightFraction: 0.52,
    builder: (context, scrollController) {
      return MarketSeriesAverageInfoSheet(scrollController: scrollController);
    },
  );
}

/// Educational disclosure for Market Detail Tier B delta lines.
class MarketSeriesAverageInfoSheet extends StatelessWidget {
  const MarketSeriesAverageInfoSheet({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bodyStyle = textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.88),
      height: 1.45,
    );

    return CollectibleSheetInsets(
      child: CollectibleSheetScrollView(
        controller: scrollController,
        header: const CollectibleSheetChrome(
          editorialTitle: kMarketSeriesAverageInfoSheetTitle,
        ),
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
                  'This comparison uses marketplace activity from the same '
                  'series, not sales of this specific figure.',
                  style: bodyStyle,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Within a blind-box series, individual figures can vary '
                  'significantly in value.',
                  style: bodyStyle,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Regular figures, popular figures, and secrets may sell for '
                  'very different prices.',
                  style: bodyStyle,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Use series averages as a general reference, not as the '
                  'market value of this figure.',
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
