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

  /// List layout: single horizontal run with middots when space allows.
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
      return Text.rich(
        TextSpan(
          style: style,
          children: [
            for (var i = 0; i < lines.length; i++) ...[
              if (i > 0)
                TextSpan(
                  text: '  ·  ',
                  style: style.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(
                  lines[i].icon,
                  size: iconSize,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                ),
              ),
              TextSpan(text: ' ${lines[i].text}'),
            ],
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
