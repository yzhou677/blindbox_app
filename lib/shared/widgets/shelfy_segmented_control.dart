import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:flutter/material.dart';

/// One option in a [ShelfySegmentedControl].
@immutable
class ShelfySegment<T> {
  const ShelfySegment({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// Soft, pill-shaped segmented control with a sliding selected thumb.
///
/// Built from Flutter primitives (no [SegmentedButton], no Material splash).
/// Selection animates via [AnimatedAlign] / [AnimatedContainer].
class ShelfySegmentedControl<T> extends StatelessWidget {
  const ShelfySegmentedControl({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
    this.height = 44,
    this.duration = CollectibleMotion.crossfade,
    this.curve = CollectibleMotion.easeOut,
  });

  final T value;
  final List<ShelfySegment<T>> segments;
  final ValueChanged<T> onChanged;

  /// Outer track height (selected thumb sits inset inside).
  final double height;

  final Duration duration;
  final Curve curve;

  static const double _trackInset = 3;
  static const double _trackRadius = 14;
  static const double _thumbRadius = 11;
  static const double _iconSize = 18;
  static const double _iconLabelGap = 8;
  static const double _segmentHorizontalPadding = 6;

  int get _selectedIndex {
    final i = segments.indexWhere((s) => s.value == value);
    return i < 0 ? 0 : i;
  }

  /// Maps segment index → [Alignment.x] for equal-width thumbs (-1 … 1).
  Alignment _thumbAlignment(int index, int count) {
    if (count <= 1) return Alignment.center;
    final x = -1.0 + (2.0 * index / (count - 1));
    return Alignment(x, 0);
  }

  @override
  Widget build(BuildContext context) {
    assert(segments.isNotEmpty, 'ShelfySegmentedControl requires segments');

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = segments.length;
    final selectedIndex = _selectedIndex;

    final trackColor = scheme.surfaceContainer.withValues(
      alpha: isDark ? 0.72 : 0.88,
    );
    // Selected thumb uses primaryContainer — same selection language as brand chips.
    final thumbColor = Color.lerp(
      scheme.surface,
      scheme.primaryContainer,
      isDark ? 0.55 : 0.72,
    )!;
    final selectedFg = scheme.onPrimaryContainer.withValues(alpha: 0.9);
    final unselectedFg = scheme.onSurfaceVariant.withValues(alpha: 0.72);
    final labelStyle = textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.08,
      height: 1.05,
    );

    return SizedBox(
      key: const Key('shelfy_segmented_control'),
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(_trackRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_trackInset),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: duration,
                curve: curve,
                alignment: _thumbAlignment(selectedIndex, count),
                child: FractionallySizedBox(
                  widthFactor: 1 / count,
                  heightFactor: 1,
                  child: AnimatedContainer(
                    duration: duration,
                    curve: curve,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: thumbColor,
                      borderRadius: BorderRadius.circular(_thumbRadius),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(
                            alpha: isDark ? 0.18 : 0.06,
                          ),
                          blurRadius: isDark ? 5 : 6,
                          offset: const Offset(0, 1),
                          spreadRadius: -1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < count; i++)
                    Expanded(
                      child: _SegmentHitTarget(
                        onTap: () {
                          final next = segments[i].value;
                          if (next == value) return;
                          onChanged(next);
                        },
                        child: _SegmentContent(
                          icon: segments[i].icon,
                          label: segments[i].label,
                          selected: i == selectedIndex,
                          selectedColor: selectedFg,
                          unselectedColor: unselectedFg,
                          labelStyle: labelStyle,
                          duration: duration,
                          curve: curve,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentHitTarget extends StatelessWidget {
  const _SegmentHitTarget({
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
  }
}

class _SegmentContent extends StatelessWidget {
  const _SegmentContent({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.labelStyle,
    required this.duration,
    required this.curve,
  });

  final IconData? icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final TextStyle? labelStyle;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ShelfySegmentedControl._segmentHorizontalPadding,
      ),
      child: Center(
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: color),
          duration: duration,
          curve: curve,
          builder: (context, animatedColor, child) {
            final c = animatedColor ?? color;
            return FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: ShelfySegmentedControl._iconSize,
                      color: c,
                    ),
                    const SizedBox(width: ShelfySegmentedControl._iconLabelGap),
                  ],
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (labelStyle ?? const TextStyle()).copyWith(
                      color: c,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
