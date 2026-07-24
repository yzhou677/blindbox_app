import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
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

    /// Discover opt-in: tighter title → subtitle gap; other surfaces keep default.
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Optional lead beside the title (e.g. fire icon for market rails).
  final Widget? titleAccessory;
  final EdgeInsetsGeometry padding;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final deck = subtitle?.trim();
    final titleStyle = AppTypography.sectionTitle(textTheme, scheme);
    final deckStyle = CollectibleTokens.of(
      context,
    ).supportiveBody(textTheme, scheme);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (titleAccessory != null) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: titleAccessory,
                ),
              ],
              Expanded(
                child: Text(
                  title,
                  style: dense
                      ? titleStyle.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        )
                      : titleStyle,
                ),
              ),
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
            SizedBox(
              height: dense
                  ? FeedRhythm.sectionTitleToSubtitle - 3
                  : FeedRhythm.sectionTitleToSubtitle,
            ),
            Text(
              d,
              style: dense
                  ? deckStyle.copyWith(height: 1.35, letterSpacing: 0.02)
                  : deckStyle,
            ),
          ],
        ],
      ),
    );
  }
}
