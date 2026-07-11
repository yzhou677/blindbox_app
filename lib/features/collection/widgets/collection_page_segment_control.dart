import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Local Shelf / Insights switch for the Collection page.
enum CollectionPageSegment { shelf, insights }

/// Material 3 segmented control for Collection page sections.
class CollectionPageSegmentControl extends StatelessWidget {
  const CollectionPageSegmentControl({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final CollectionPageSegment selected;
  final ValueChanged<CollectionPageSegment> onChanged;

  static const double _controlHeight = 54;
  static const double _trackInset = 4;
  static const double _trackRadius = 18;
  static const double _segmentRadius = 14;
  static const double _iconSize = 20;
  static const double _segmentHeight = _controlHeight - (_trackInset * 2);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelStyle = textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      height: 1.1,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        FeedRhythm.collectionSummaryToSegmentGap,
        AppSpacing.pageHorizontal,
        FeedRhythm.collectionSegmentToShelfHeader,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(
            alpha: isDark ? 0.72 : 0.92,
          ),
          borderRadius: BorderRadius.circular(_trackRadius),
        ),
        child: SizedBox(
          height: _controlHeight,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(_trackInset),
            child: SegmentedButton<CollectionPageSegment>(
              segments: [
                ButtonSegment<CollectionPageSegment>(
                  value: CollectionPageSegment.shelf,
                  label: _SegmentLabel(
                    icon: Icons.grid_view_rounded,
                    text: 'Shelf',
                    style: labelStyle,
                  ),
                ),
                ButtonSegment<CollectionPageSegment>(
                  value: CollectionPageSegment.insights,
                  label: _SegmentLabel(
                    icon: Icons.auto_awesome_rounded,
                    text: 'Insights',
                    style: labelStyle,
                  ),
                ),
              ],
              selected: {selected},
              onSelectionChanged: (next) {
                if (next.isEmpty) return;
                onChanged(next.first);
              },
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.standard,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const WidgetStatePropertyAll(
                  Size(0, _segmentHeight),
                ),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 24),
                ),
                shape: const WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(_segmentRadius),
                    ),
                  ),
                ),
                textStyle: WidgetStatePropertyAll(labelStyle),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return scheme.surface.withValues(alpha: isDark ? 0.94 : 1);
                  }
                  return Colors.transparent;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return scheme.onSurface.withValues(alpha: 0.94);
                  }
                  return scheme.onSurfaceVariant.withValues(alpha: 0.78);
                }),
                elevation: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return isDark ? 0.5 : 1.5;
                  }
                  return 0;
                }),
                shadowColor: WidgetStatePropertyAll(
                  scheme.shadow.withValues(alpha: isDark ? 0.35 : 0.18),
                ),
                side: const WidgetStatePropertyAll(BorderSide.none),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon + label as one centered group (avoids SegmentedButton icon offset).
class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({
    required this.icon,
    required this.text,
    required this.style,
  });

  final IconData icon;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: CollectionPageSegmentControl._iconSize),
        const SizedBox(width: 8),
        Text(text, style: style),
      ],
    );
  }
}
