import 'package:blindbox_app/features/market/utils/listing_description_text.dart';
import 'package:flutter/material.dart';

/// Collapsible body copy with fade, animated height, and read-more control.
class ExpandableDescription extends StatefulWidget {
  const ExpandableDescription({
    super.key,
    required this.text,
    required this.style,
    this.collapsedMaxLines = 5,
    this.fadeHeight = 28,
    this.animationDuration = const Duration(milliseconds: 280),
    this.animationCurve = Curves.easeOutCubic,
    this.backgroundColor,
  });

  final String text;
  final TextStyle style;
  final int collapsedMaxLines;
  final double fadeHeight;
  final Duration animationDuration;
  final Curve animationCurve;

  /// Background behind the bottom fade — should match the hosting surface.
  final Color? backgroundColor;

  @override
  State<ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fadeBase = widget.backgroundColor ?? scheme.surface;
    final textDirection = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final showToggle = listingDescriptionExceedsCollapsedLines(
          text: widget.text,
          style: widget.style,
          maxWidth: constraints.maxWidth,
          maxLines: widget.collapsedMaxLines,
          textDirection: textDirection,
        );
        final collapsed = showToggle && !_expanded;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: widget.animationDuration,
              curve: widget.animationCurve,
              alignment: Alignment.topLeft,
              clipBehavior: Clip.none,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(
                    widget.text,
                    style: widget.style,
                    maxLines: collapsed ? widget.collapsedMaxLines : null,
                    overflow: collapsed ? TextOverflow.clip : null,
                  ),
                  if (collapsed)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: widget.fadeHeight,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                fadeBase.withValues(alpha: 0),
                                fadeBase,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (showToggle) ...[
              const SizedBox(height: 6),
              _DescriptionToggle(
                expanded: _expanded,
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DescriptionToggle extends StatelessWidget {
  const _DescriptionToggle({
    required this.expanded,
    required this.onPressed,
  });

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: scheme.primary.withValues(
            alpha: scheme.brightness == Brightness.dark ? 0.92 : 0.88,
          ),
        ),
        child: Text(
          expanded ? 'Show less' : 'Read more',
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
