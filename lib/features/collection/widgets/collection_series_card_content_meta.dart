import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/core/theme/shelfy_symbols.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_card_content.dart';
import 'package:flutter/material.dart';

/// Compact optional metadata block for Series Cards (Grid / Compact / List).
class CollectionSeriesCardContentMeta extends StatelessWidget {
  const CollectionSeriesCardContentMeta({
    super.key,
    required this.lines,
    this.compact = false,
    this.horizontal = false,
  });

  final List<CollectionShelfCardContentLine> lines;
  final bool compact;

  /// List layout: each selected Card Content field gets its own full-width row
  /// (no middot compression). Duplicate copy may wrap up to 2 lines.
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final style = CollectibleTypography.seriesIpLine(
      textTheme,
      scheme,
    ).copyWith(fontSize: compact ? 10.5 : 12, height: 1.2);
    final iconSize = compact ? 12.0 : AppIconSizes.metadata * 0.85;
    final gap = compact ? 2.0 : 3.0;

    if (horizontal) {
      return _ListStackedMeta(
        lines: lines,
        style: style,
        iconSize: iconSize,
        rowGap: gap,
        scheme: scheme,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          Row(
            children: [
              Icon(
                lines[i].icon,
                size: iconSize,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  lines[i].text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// List-only: stack every Card Content line on its own row at full width.
/// Omits empty rows when fewer than two fields have values.
class _ListStackedMeta extends StatelessWidget {
  const _ListStackedMeta({
    required this.lines,
    required this.style,
    required this.iconSize,
    required this.rowGap,
    required this.scheme,
  });

  final List<CollectionShelfCardContentLine> lines;
  final TextStyle style;
  final double iconSize;
  final double rowGap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) SizedBox(height: rowGap),
          _ListMetaRow(
            key: Key('collection_series_list_meta_line_$i'),
            line: lines[i],
            style: style,
            iconSize: iconSize,
            scheme: scheme,
          ),
        ],
      ],
    );
  }
}

class _ListMetaRow extends StatelessWidget {
  const _ListMetaRow({
    super.key,
    required this.line,
    required this.style,
    required this.iconSize,
    required this.scheme,
  });

  final CollectionShelfCardContentLine line;
  final TextStyle style;
  final double iconSize;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final isDuplicate =
        line.field == CollectionShelfCardContentField.duplicateCount;
    return Row(
      key: isDuplicate
          ? const Key('collection_series_list_meta_duplicate')
          : null,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            line.icon,
            size: iconSize,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            line.text,
            maxLines: isDuplicate ? 2 : 1,
            softWrap: isDuplicate,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}
