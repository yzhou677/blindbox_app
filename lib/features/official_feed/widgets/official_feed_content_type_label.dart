import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_content_type_style.dart';
import 'package:flutter/material.dart';

/// Soft tinted pill for the per-card content-type deck line.
class OfficialFeedContentTypeLabel extends StatelessWidget {
  const OfficialFeedContentTypeLabel({super.key, required this.item});

  final OfficialFeedItem item;

  static const double _iconSize = 11;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final style = OfficialFeedContentTypeStyles.forItem(
      item,
      scheme,
      isDark: isDark,
    );

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
              Icon(icon, size: _iconSize, color: style.foreground),
              const SizedBox(width: 3),
            ],
            Text(
              style.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.02,
                height: 1.2,
                color: style.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
