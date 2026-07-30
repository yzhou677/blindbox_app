import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_content_type_style.dart';
import 'package:flutter/material.dart';

/// Soft tinted pill(s) for per-card content-type deck lines (1–2 tags).
///
/// Always a single horizontal row — pills shrink with ellipsis instead of wrapping.
class OfficialFeedContentTypeLabel extends StatelessWidget {
  const OfficialFeedContentTypeLabel({super.key, required this.item});

  final OfficialFeedItem item;

  static const double _iconSize = 11;
  static const double _pillGap = 4;
  static const tagsRowKey = Key('official_feed_tags_row');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final styles = OfficialFeedContentTypeStyles.forItem(
      item,
      scheme,
      isDark: isDark,
    );

    return KeyedSubtree(
      key: tagsRowKey,
      child: Row(
        children: [
          for (var i = 0; i < styles.length; i++) ...[
            if (i > 0) const SizedBox(width: _pillGap),
            Flexible(
              child: _TagPill(style: styles[i], theme: theme),
            ),
          ],
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.style, required this.theme});

  final OfficialFeedContentTypeStyle style;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (style.icon case final icon?) ...[
              Icon(
                icon,
                size: OfficialFeedContentTypeLabel._iconSize,
                color: style.foreground,
              ),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                style.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.02,
                  height: 1.2,
                  color: style.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
