import 'dart:math' as math;

import 'package:blindbox_app/features/collection/insights/presentation/collector_type_palette.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:flutter/material.dart';

class CollectorTypeBrandDonut extends StatefulWidget {
  const CollectorTypeBrandDonut({
    super.key,
    required this.brandBreakdown,
    this.size = 132,
    this.onSectorTap,
  });

  final Map<String, int> brandBreakdown;
  final double size;
  final ValueChanged<String>? onSectorTap;

  @override
  State<CollectorTypeBrandDonut> createState() => _CollectorTypeBrandDonutState();
}

class _CollectorTypeBrandDonutState extends State<CollectorTypeBrandDonut>
    with SingleTickerProviderStateMixin {
  static const double _tapTargetPadding = 16;
  static const double _tapTolerance = 8;

  late final AnimationController _sweep;
  String? _selectedBrandId;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    )..forward();
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = widget.brandBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Center(
          child: Text(
            '—',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
          ),
        ),
      );
    }

    final total = entries.fold<int>(0, (s, e) => s + e.value);
    final selectedLabel = _selectedBrandId == null
        ? null
        : (MarketTaxonomy.brandById(_selectedBrandId!)?.displayLabel ??
            _selectedBrandId);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final canvasOffset = details.localPosition -
                const Offset(_tapTargetPadding, _tapTargetPadding);
            final brandId = _brandAtOffset(
              canvasOffset,
              entries,
              total,
            );
            if (brandId != null) {
              setState(() => _selectedBrandId = brandId);
              widget.onSectorTap?.call(brandId);
            }
          },
          child: SizedBox.square(
            dimension: widget.size + (_tapTargetPadding * 2),
            child: Center(
              child: AnimatedBuilder(
                animation: _sweep,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size.square(widget.size),
                    painter: _BrandDonutPainter(
                      entries: entries,
                      total: total,
                      sweep: Curves.easeOutCubic.transform(_sweep.value),
                      colors: CollectorTypePalette.sectorColors,
                      centerFill: scheme.surfaceContainerLow,
                      centerTextColor: scheme.onSurface.withValues(alpha: 0.88),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (selectedLabel != null) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              selectedLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                  ),
            ),
          ),
        ],
      ],
    );
  }

  String? _brandAtOffset(
    Offset local,
    List<MapEntry<String, int>> entries,
    int total,
  ) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final v = local - center;
    final r = v.distance;
    final outer = widget.size / 2;
    final inner = outer * 0.52;
    if (r < inner - _tapTolerance || r > outer + _tapTolerance) return null;

    var angle = math.atan2(v.dy, v.dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;

    var cursor = 0.0;
    for (final e in entries) {
      final sweep = (e.value / total) * 2 * math.pi;
      if (angle >= cursor && angle < cursor + sweep) return e.key;
      cursor += sweep;
    }
    return entries.last.key;
  }
}

class _BrandDonutPainter extends CustomPainter {
  _BrandDonutPainter({
    required this.entries,
    required this.total,
    required this.sweep,
    required this.colors,
    required this.centerFill,
    required this.centerTextColor,
  });

  final List<MapEntry<String, int>> entries;
  final int total;
  final double sweep;
  final List<Color> colors;
  final Color centerFill;
  final Color centerTextColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = size.width / 2;
    final inner = outer * 0.52;
    final rect = Rect.fromCircle(center: center, radius: outer);

    var start = -math.pi / 2;
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final fullSweep = (entry.value / total) * 2 * math.pi;
      final drawSweep = fullSweep * sweep;
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = outer - inner
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, drawSweep, false, paint);
      start += fullSweep;
    }

    final hole = Paint()..color = centerFill;
    canvas.drawCircle(center, inner - 1, hole);

    final textPainter = TextPainter(
      text: TextSpan(
        text: '$total',
        style: TextStyle(
          fontSize: size.width * 0.22,
          fontWeight: FontWeight.w600,
          color: centerTextColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _BrandDonutPainter oldDelegate) =>
      oldDelegate.sweep != sweep || oldDelegate.entries != entries;
}
