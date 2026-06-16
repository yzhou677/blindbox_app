import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_sheet_chrome.dart';
import 'package:flutter/material.dart';

/// Semantics label for the Shelf Value section info affordance.
const String kShelfValueInfoSemanticsLabel = 'How shelf value is calculated';

/// Bottom sheet title — matches disclosure copy in Sprint 3M-B.
const String kShelfValueInfoSheetTitle = 'How shelf value is calculated';

/// Opens the Shelf Value transparency bottom sheet.
Future<void> showShelfValueInfoSheet(BuildContext context) {
  return showCollectibleBottomSheet<void>(
    context: context,
    heightFraction: 0.52,
    builder: (context, scrollController) {
      return ShelfValueInfoSheet(scrollController: scrollController);
    },
  );
}

/// Educational disclosure for Collection Insights shelf value totals.
class ShelfValueInfoSheet extends StatelessWidget {
  const ShelfValueInfoSheet({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bodyStyle = textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.88),
      height: 1.45,
    );
    final headingStyle = textTheme.titleSmall?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.9),
      fontWeight: FontWeight.w600,
      height: 1.3,
    );

    return CollectibleSheetInsets(
      child: CollectibleSheetScrollView(
        controller: scrollController,
        header: const CollectibleSheetChrome(
          editorialTitle: kShelfValueInfoSheetTitle,
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
                  'We estimate the value of figures you own using recent '
                  'marketplace activity.',
                  style: bodyStyle,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Figure Snapshot', style: headingStyle),
                const SizedBox(height: 6),
                Text(
                  'Based on sales of that exact figure.',
                  style: bodyStyle,
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Series Estimate', style: headingStyle),
                const SizedBox(height: 6),
                Text(
                  'Based on marketplace activity from the same series when '
                  'figure-specific data is limited.',
                  style: bodyStyle,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '• "~" means approximate.',
                  style: bodyStyle,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '• "includes estimates" means one or more figures used a '
                  'Series Estimate.',
                  style: bodyStyle,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Figures without market data are excluded.',
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
