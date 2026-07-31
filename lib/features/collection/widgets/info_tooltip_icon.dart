import 'dart:math' as math;

import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class InfoTooltipIcon extends StatefulWidget {
  const InfoTooltipIcon({
    super.key,
    required this.message,
    required this.color,
    this.size = 14,
    this.semanticLabel = 'More information',
    this.minTapExtent,
    this.tapAlignment = Alignment.center,
  });

  final String message;
  final Color color;
  final double size;

  /// Accessibility label for the info control (distinct from [message]).
  final String semanticLabel;

  /// When set, expands the hit target to at least this square extent.
  final double? minTapExtent;

  /// Where the glyph sits inside [minTapExtent] (e.g. [Alignment.centerLeft]
  /// to sit flush beside a label while the tap area extends outward).
  final AlignmentGeometry tapAlignment;

  @override
  State<InfoTooltipIcon> createState() => _InfoTooltipIconState();
}

class _InfoTooltipIconState extends State<InfoTooltipIcon> {
  static VoidCallback? _dismissActiveTooltip;
  static final Set<_InfoTooltipIconState> _instances = {};

  OverlayEntry? _entry;
  ScrollPosition? _scrollPosition;
  VoidCallback? _scrollListener;

  @override
  void initState() {
    super.initState();
    _instances.add(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _detachScrollListener();
    final scrollable = Scrollable.maybeOf(context);
    final position = scrollable?.position;
    if (position == null) return;

    void listener() {
      if (position.isScrollingNotifier.value) {
        _dismiss();
      }
    }

    position.isScrollingNotifier.addListener(listener);
    _scrollPosition = position;
    _scrollListener = listener;
  }

  @override
  void dispose() {
    _instances.remove(this);
    _detachScrollListener();
    _dismiss();
    super.dispose();
  }

  void _detachScrollListener() {
    final position = _scrollPosition;
    final listener = _scrollListener;
    if (position != null && listener != null) {
      position.isScrollingNotifier.removeListener(listener);
    }
    _scrollPosition = null;
    _scrollListener = null;
  }

  void _toggle() {
    if (_entry != null) {
      _dismiss();
      return;
    }
    _show();
  }

  void _show() {
    final overlay = Overlay.maybeOf(context);
    final renderObject = context.findRenderObject();
    if (overlay == null ||
        renderObject is! RenderBox ||
        !renderObject.hasSize) {
      return;
    }

    _dismissActiveTooltip?.call();

    final iconRect =
        renderObject.localToGlobal(Offset.zero) & renderObject.size;
    final media = MediaQuery.of(context);
    final textScale = MediaQuery.textScalerOf(context);
    final screenSize = media.size;
    const margin = 16.0;
    const bubblePadH = 15.0 * 2;
    const bubblePadV = 13.0 * 2;
    const arrowExtent = 10.0;
    final availableWidth = math.max(0.0, screenSize.width - margin * 2);
    final maxBubbleWidth = availableWidth < 240
        ? availableWidth
        : math.min(280.0, availableWidth);

    final messageStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 13,
          height: 1.38,
          fontWeight: FontWeight.w400,
        ) ??
        const TextStyle(fontSize: 13, height: 1.38);
    final painter = TextPainter(
      text: TextSpan(text: widget.message, style: messageStyle),
      textDirection: Directionality.of(context),
      textScaler: textScale,
    )..layout(maxWidth: math.max(0.0, maxBubbleWidth - bubblePadH));

    // Size the overlay to the message — avoid a large empty bubble.
    final width = (painter.width + bubblePadH)
        .clamp(math.min(160.0, maxBubbleWidth), maxBubbleWidth)
        .toDouble();
    final left = (iconRect.center.dx - width / 2)
        .clamp(margin, screenSize.width - width - margin)
        .toDouble();
    const gap = 9.0;
    final bottomLimit = screenSize.height - media.padding.bottom - 24;
    final estimatedHeight = painter.height + bubblePadV + arrowExtent + gap;
    final topBelow = iconRect.bottom + gap;
    final placeAbove = topBelow + estimatedHeight > bottomLimit;
    final top = placeAbove
        ? math.max(
            media.padding.top + margin,
            iconRect.top - estimatedHeight - gap,
          )
        : topBelow;
    final arrowCenterX = (iconRect.center.dx - left)
        .clamp(16.0, width - 16.0)
        .toDouble();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AnchoredTooltipOverlay(
        message: widget.message,
        left: left,
        top: top,
        width: width,
        arrowCenterX: arrowCenterX,
        placeAbove: placeAbove,
        onOutsideTap: _handleOutsideTap,
      ),
    );
    _entry = entry;
    _dismissActiveTooltip = _dismiss;
    overlay.insert(entry);
  }

  void _dismiss() {
    if (_dismissActiveTooltip == _dismiss) {
      _dismissActiveTooltip = null;
    }
    _entry?.remove();
    _entry = null;
  }

  void _handleOutsideTap(Offset globalPosition) {
    for (final instance in List<_InfoTooltipIconState>.of(_instances)) {
      if (instance == this || !instance.mounted) continue;
      if (instance._containsGlobalPosition(globalPosition)) {
        instance._show();
        return;
      }
    }
    _dismiss();
  }

  bool _containsGlobalPosition(Offset globalPosition) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;
    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    return rect.inflate(8).contains(globalPosition);
  }

  @override
  Widget build(BuildContext context) {
    final minExtent = widget.minTapExtent;
    final icon = Padding(
      padding: const EdgeInsets.all(3),
      child: Icon(Symbols.info_rounded, size: widget.size, color: widget.color),
    );

    return Semantics(
      key: ValueKey<String>('info-tooltip-${widget.message}'),
      button: true,
      tooltip: widget.message,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: minExtent == null
            ? icon
            : _MinTapTarget(
                minExtent: minExtent,
                alignment: widget.tapAlignment,
                child: icon,
              ),
      ),
    );
  }
}

/// Ensures a [minExtent] hit width/height when needed.
///
/// Horizontal-biased alignments ([Alignment.centerLeft] / [Alignment.centerRight])
/// only force width so dense meta rows are not padded by empty vertical tap
/// chrome; the glyph height remains the layout height.
class _MinTapTarget extends StatelessWidget {
  const _MinTapTarget({
    required this.minExtent,
    required this.alignment,
    required this.child,
  });

  final double minExtent;
  final AlignmentGeometry alignment;
  final Widget child;

  bool get _layoutFollowsGlyph {
    final resolved = alignment.resolve(null);
    return resolved.x.abs() > 0.01 && resolved.y.abs() < 0.01;
  }

  @override
  Widget build(BuildContext context) {
    if (_layoutFollowsGlyph) {
      return SizedBox(
        width: minExtent,
        child: Align(alignment: alignment, child: child),
      );
    }
    return SizedBox(
      width: minExtent,
      height: minExtent,
      child: Align(alignment: alignment, child: child),
    );
  }
}

class _AnchoredTooltipOverlay extends StatelessWidget {
  const _AnchoredTooltipOverlay({
    required this.message,
    required this.left,
    required this.top,
    required this.width,
    required this.arrowCenterX,
    required this.placeAbove,
    required this.onOutsideTap,
  });

  final String message;
  final double left;
  final double top;
  final double width;
  final double arrowCenterX;
  final bool placeAbove;
  final ValueChanged<Offset> onOutsideTap;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) => onOutsideTap(details.globalPosition),
            child: const SizedBox.expand(),
          ),
          Positioned(
            left: left,
            top: top,
            width: width,
            child: _TooltipBubble(
              message: message,
              arrowCenterX: arrowCenterX,
              placeAbove: placeAbove,
            ),
          ),
        ],
      ),
    );
  }
}

class _TooltipBubble extends StatelessWidget {
  const _TooltipBubble({
    required this.message,
    required this.arrowCenterX,
    required this.placeAbove,
  });

  final String message;
  final double arrowCenterX;
  final bool placeAbove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = Color.lerp(
      scheme.outlineVariant,
      scheme.primary,
      isDark ? 0.16 : 0.12,
    )!;
    final background = Color.lerp(
      scheme.surfaceContainerHighest,
      scheme.surface,
      isDark ? 0.18 : 0.42,
    )!;
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.26 : 0.1);

    final bubble = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: CollectibleShape.matRadius,
        border: Border.all(color: borderColor.withValues(alpha: 0.64)),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 18,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.86),
            fontSize: 13,
            height: 1.38,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );

    return Semantics(
      liveRegion: true,
      label: message,
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: placeAbove
              ? [
                  bubble,
                  _TooltipArrow(
                    x: arrowCenterX,
                    pointsUp: false,
                    color: background,
                    borderColor: borderColor,
                  ),
                ]
              : [
                  _TooltipArrow(
                    x: arrowCenterX,
                    pointsUp: true,
                    color: background,
                    borderColor: borderColor,
                  ),
                  bubble,
                ],
        ),
      ),
    );
  }
}

class _TooltipArrow extends StatelessWidget {
  const _TooltipArrow({
    required this.x,
    required this.pointsUp,
    required this.color,
    required this.borderColor,
  });

  final double x;
  final bool pointsUp;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: x - 5),
      child: CustomPaint(
        size: const Size(10, 5),
        painter: _TooltipArrowPainter(
          pointsUp: pointsUp,
          color: color,
          borderColor: borderColor.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _TooltipArrowPainter extends CustomPainter {
  const _TooltipArrowPainter({
    required this.pointsUp,
    required this.color,
    required this.borderColor,
  });

  final bool pointsUp;
  final Color color;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointsUp) {
      path
        ..moveTo(size.width / 2, 0)
        ..quadraticBezierTo(
          size.width * 0.68,
          size.height * 0.42,
          size.width,
          size.height,
        )
        ..lineTo(0, size.height)
        ..quadraticBezierTo(
          size.width * 0.32,
          size.height * 0.42,
          size.width / 2,
          0,
        )
        ..close();
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..quadraticBezierTo(
          size.width * 0.68,
          size.height * 0.58,
          size.width / 2,
          size.height,
        )
        ..quadraticBezierTo(size.width * 0.32, size.height * 0.58, 0, 0)
        ..close();
    }

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_TooltipArrowPainter oldDelegate) {
    return pointsUp != oldDelegate.pointsUp ||
        color != oldDelegate.color ||
        borderColor != oldDelegate.borderColor;
  }
}
