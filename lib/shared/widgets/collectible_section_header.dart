import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/collectible_tokens.dart';
import 'package:flutter/material.dart';

/// Section rhythm: soft lead, title row, optional subtitle deck.
class CollectibleSectionHeader extends StatelessWidget {
  const CollectibleSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.titleAccessory,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 0),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Replaces the default tiny sparkle (e.g. fire icon for market rails).
  final Widget? titleAccessory;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final lead =
        titleAccessory ??
        Icon(
          Icons.auto_awesome_rounded,
          size: 15,
          color: scheme.primary.withValues(alpha: 0.3),
        );

    final deck = subtitle?.trim();

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(padding: const EdgeInsets.only(right: 8), child: lead),
              Expanded(child: Text(title, style: textTheme.titleMedium)),
              if (trailing case final t?) ...[
                const SizedBox(width: 8),
                Flexible(
                  fit: FlexFit.loose,
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: t,
                  ),
                ),
              ],
            ],
          ),
          if (deck case final d? when d.isNotEmpty) ...[
            const SizedBox(height: FeedRhythm.sectionTitleToSubtitle),
            Text(
              d,
              style: CollectibleTokens.of(
                context,
              ).supportiveBody(textTheme, scheme),
            ),
          ],
        ],
      ),
    );
  }
}
