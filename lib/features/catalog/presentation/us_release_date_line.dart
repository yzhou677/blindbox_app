import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/catalog/presentation/us_release_date_copy.dart';
import 'package:blindbox_app/features/collection/widgets/info_tooltip_icon.dart';
import 'package:flutter/material.dart';

/// Compact U.S. release-date meta for Series Detail surfaces (secondary to
/// title/art). Hides entirely when [releaseDate] is null or cannot be formatted.
///
/// Used on Discover drop detail, catalog series preview, and Collection series
/// figures sheets — not Market.
class UsReleaseDateLine extends StatelessWidget {
  const UsReleaseDateLine({super.key, required this.releaseDate});

  final DateTime? releaseDate;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final line = formatUsReleaseDateLine(releaseDate, localizations);
    if (line == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final style = CollectibleTypography.figureMeta(textTheme, scheme);

    // Keep the date in the Series summary cluster (~12 above trailing meta).
    // Gap below to the section rule is owned by Series Detail sliver padding.
    return Padding(
      key: const Key('us_release_date_line'),
      padding: const EdgeInsets.only(top: FeedRhythm.sheetLabelToControl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              line,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          InfoTooltipIcon(
            key: const Key('us_release_date_info'),
            message: UsReleaseDateCopy.disclosure,
            semanticLabel: UsReleaseDateCopy.infoSemanticLabel,
            size: AppSpacing.md,
            minTapExtent: 48,
            tapAlignment: Alignment.centerLeft,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.54),
          ),
        ],
      ),
    );
  }
}
