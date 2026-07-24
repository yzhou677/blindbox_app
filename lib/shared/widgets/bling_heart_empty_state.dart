import 'package:blindbox_app/core/theme/shelfy_symbols.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Wishlist empty-state hero: unchanged outline heart with a quiet printed glow
/// and hand-drawn sparkles (no Material star glyphs, no motion).
class BlingHeartEmptyState extends StatelessWidget {
  const BlingHeartEmptyState({super.key, this.heartKey});

  /// Forwarded to the heart [Icon] (tests / semantics anchors).
  final Key? heartKey;

  static const double _layoutSize = AppIconSizes.emptyHero;

  /// Sparkles paint outside the layout box without shifting title spacing.
  static const double _sparkleBleed = 26;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;

    return SizedBox(
      width: _layoutSize,
      height: _layoutSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(_layoutSize, _layoutSize),
            painter: _BlingHeartGlowPainter(color: primary),
          ),
          Positioned(
            left: -_sparkleBleed,
            top: -_sparkleBleed,
            right: -_sparkleBleed,
            bottom: -_sparkleBleed,
            child: CustomPaint(
              painter: _BlingHeartSparklePainter(color: primary),
            ),
          ),
          Icon(
            Symbols.favorite_rounded,
            key: heartKey ?? const Key('wishlist_empty_heart_icon'),
            size: AppIconSizes.emptyHero,
            fill: ShelfySymbols.fillOutline,
            weight: ShelfySymbols.emptyStateWeight,
            grade: ShelfySymbols.grade,
            opticalSize: ShelfySymbols.emptyStateOpticalSize,
            color: primary.withValues(alpha: 0.75),
          ),
        ],
      ),
    );
  }
}

/// Soft primary radial wash — almost dissolves into the page.
class _BlingHeartGlowPainter extends CustomPainter {
  _BlingHeartGlowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.52;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.15),
          color.withValues(alpha: 0.06),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _BlingHeartGlowPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Six four-point stars + two quiet dots — curated, balanced, intentionally faint.
class _BlingHeartSparklePainter extends CustomPainter {
  _BlingHeartSparklePainter({required this.color});

  final Color color;

  /// Positions are fractions of the sparkle canvas (heart + bleed).
  static const List<_SparkleSpec> _stars = [
    _SparkleSpec(dx: 0.18, dy: 0.20, size: 5.5, opacity: 0.34, rotation: 0.12),
    _SparkleSpec(dx: 0.82, dy: 0.18, size: 4.2, opacity: 0.28, rotation: -0.2),
    _SparkleSpec(dx: 0.90, dy: 0.48, size: 6.5, opacity: 0.30, rotation: 0.08),
    _SparkleSpec(dx: 0.78, dy: 0.78, size: 4.0, opacity: 0.24, rotation: 0.35),
    _SparkleSpec(dx: 0.14, dy: 0.58, size: 5.0, opacity: 0.32, rotation: -0.15),
    _SparkleSpec(dx: 0.28, dy: 0.86, size: 4.6, opacity: 0.26, rotation: 0.22),
  ];

  static const List<_DotSpec> _dots = [
    _DotSpec(dx: 0.62, dy: 0.12, radius: 1.6, opacity: 0.36),
    _DotSpec(dx: 0.10, dy: 0.38, radius: 1.25, opacity: 0.30),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in _stars) {
      final center = Offset(size.width * star.dx, size.height * star.dy);
      final paint = Paint()
        ..color = color.withValues(alpha: star.opacity)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(star.rotation);
      canvas.drawPath(_fourPointSparkle(star.size), paint);
      canvas.restore();
    }

    for (final dot in _dots) {
      final paint = Paint()
        ..color = color.withValues(alpha: dot.opacity)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawCircle(
        Offset(size.width * dot.dx, size.height * dot.dy),
        dot.radius,
        paint,
      );
    }
  }

  /// Soft four-point sparkle with a concave waist (printed-illustration feel).
  static Path _fourPointSparkle(double size) {
    final outer = size / 2;
    final inner = size * 0.14;
    return Path()
      ..moveTo(0, -outer)
      ..lineTo(inner, -inner)
      ..lineTo(outer, 0)
      ..lineTo(inner, inner)
      ..lineTo(0, outer)
      ..lineTo(-inner, inner)
      ..lineTo(-outer, 0)
      ..lineTo(-inner, -inner)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _BlingHeartSparklePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SparkleSpec {
  const _SparkleSpec({
    required this.dx,
    required this.dy,
    required this.size,
    required this.opacity,
    required this.rotation,
  });

  final double dx;
  final double dy;
  final double size;
  final double opacity;
  final double rotation;
}

class _DotSpec {
  const _DotSpec({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.opacity,
  });

  final double dx;
  final double dy;
  final double radius;
  final double opacity;
}
