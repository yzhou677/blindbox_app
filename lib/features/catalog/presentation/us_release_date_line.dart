import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/catalog/presentation/us_release_date_copy.dart';
import 'package:blindbox_app/features/collection/widgets/info_tooltip_icon.dart';
import 'package:flutter/material.dart';

/// Compact release-date meta for Series Detail surfaces (secondary to
/// title/art). Hides entirely when [releaseDate] is null or cannot be formatted.
///
/// Official catalog dates use **U.S.** copy + disclosure. User-authored custom
/// series dates use a quieter "Release Date" line without the website note.
///
/// Used on Discover drop detail, catalog series preview, and Collection series
/// figures sheets — not Market.
class UsReleaseDateLine extends StatelessWidget {
  const UsReleaseDateLine({
    super.key,
    required this.releaseDate,
    this.officialUs = true,
  });

  final DateTime? releaseDate;

  /// When false, formats as `Release Date · …` without the U.S. site disclosure.
  final bool officialUs;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final value = formatUsReleaseDateValue(releaseDate, localizations);
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    final line = officialUs
        ? '${UsReleaseDateCopy.label} · $value'
        : 'Release Date · $value';

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
          if (officialUs)
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
