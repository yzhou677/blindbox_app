import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Packaging-card style placeholder when there is no photo — reads like a tiny vinyl / blind-box tile.
class CollectibleFigurePlaceholder extends StatelessWidget {
  const CollectibleFigurePlaceholder({
    super.key,
    required this.name,
    required this.seedKey,
    this.isSecret = false,
    this.compact = false,
  });

  final String name;
  final String seedKey;
  final bool isSecret;
  final bool compact;

  static String initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final w = parts[0];
      if (w.length >= 2) return w.substring(0, 2).toUpperCase();
      return w[0].toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static (Color light, Color deep, Color accent) _palette(String seed) {
    final h = seed.hashCode.abs() % 360;
    final light = HSLColor.fromAHSL(1, h.toDouble(), 0.36, 0.94).toColor();
    final deep = HSLColor.fromAHSL(1, (h + 22) % 360.0, 0.48, 0.68).toColor();
    final accent = HSLColor.fromAHSL(
      1,
      (h + 200) % 360.0,
      0.55,
      0.62,
    ).toColor();
    return (light, deep, accent);
  }

  static int personalityVariant(String seed) => seed.hashCode.abs() % 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (light, deep, accent) = _palette(seedKey);
    final initials = initialsFor(name);
    final variant = personalityVariant(seedKey);
    final rOuter = compact ? 11.0 : 15.0;
    final rInner = compact ? 8.0 : 12.0;

    final letterStyle = (compact ? textTheme.titleSmall : textTheme.titleLarge)
        ?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: compact ? -0.15 : -0.35,
          color: deep.withValues(alpha: 0.9),
          height: 1,
          shadows: [
            Shadow(
              color: Colors.white.withValues(alpha: 0.55),
              blurRadius: compact ? 2 : 4,
              offset: const Offset(0, 0.5),
            ),
          ],
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(rOuter),
        boxShadow: [
          BoxShadow(
            color: deep.withValues(alpha: compact ? 0.08 : 0.1),
            blurRadius: compact ? 6 : 10,
            offset: Offset(0, compact ? 3 : 5),
            spreadRadius: -1,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.55),
            blurRadius: 0,
            offset: const Offset(0, -0.5),
            spreadRadius: 0,
          ),
        ],
        border: Border.all(
          color: Color.lerp(
            deep,
            scheme.outline,
            0.35,
          )!.withValues(alpha: 0.35),
          width: compact ? 1 : 1.15,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(light, Colors.white, 0.28)!,
            Color.lerp(light, deep, 0.08)!,
            Color.lerp(deep, light, 0.15)!.withValues(alpha: 0.85),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 3 : 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(rInner),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.55),
              width: 1,
            ),
            gradient: RadialGradient(
              center: const Alignment(0, -0.55),
              radius: 1.15,
              colors: [
                Colors.white.withValues(alpha: 0.42),
                light.withValues(alpha: 0.15),
                deep.withValues(alpha: 0.12),
              ],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(rInner - 1),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BlisterShelfBackdrop(
                      accent: accent.withValues(alpha: compact ? 0.12 : 0.16),
                      compact: compact,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ToySilhouettePainter(
                      variant: variant,
                      seed: seedKey,
                      fill: deep.withValues(alpha: compact ? 0.14 : 0.17),
                      accent: accent.withValues(alpha: 0.22),
                      isSecret: isSecret,
                      compact: compact,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(painter: _BlisterGloss(compact: compact)),
                ),
                if (!compact)
                  Positioned(
                    top: 5,
                    left: 6,
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withValues(alpha: 0.75),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.35),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: deep.withValues(alpha: 0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
                Center(child: Text(initials, style: letterStyle)),
                if (isSecret && !compact)
                  Positioned(
                    bottom: 5,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 11,
                          color: deep.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'chase',
                          style: textTheme.labelSmall?.copyWith(
                            color: deep.withValues(alpha: 0.62),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.35,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft “blister plastic” shelf reflection.
class _BlisterGloss extends CustomPainter {
  _BlisterGloss({required this.compact});

  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final r = BorderRadius.circular(
      compact ? 8 : 12,
    ).toRRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.15, 0),
        Offset(size.width * 0.9, size.height * 0.95),
        [
          Colors.white.withValues(alpha: 0.38),
          Colors.white.withValues(alpha: 0.05),
          Colors.white.withValues(alpha: 0),
        ],
        const [0.0, 0.35, 0.7],
      );
    canvas.drawRRect(r, paint);
  }

  @override
  bool shouldRepaint(covariant _BlisterGloss oldDelegate) =>
      oldDelegate.compact != compact;
}

class _BlisterShelfBackdrop extends CustomPainter {
  _BlisterShelfBackdrop({required this.accent, required this.compact});

  final Color accent;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final oval = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.72),
      width: size.width * (compact ? 0.95 : 1.05),
      height: size.height * (compact ? 0.42 : 0.48),
    );
    final paint = Paint()
      ..shader = ui.Gradient.radial(oval.center, oval.longestSide * 0.45, [
        accent,
        accent.withValues(alpha: 0),
      ]);
    canvas.drawOval(oval, paint);
  }

  @override
  bool shouldRepaint(covariant _BlisterShelfBackdrop oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.compact != compact;
}

/// Soft vinyl-like silhouette — not a flat icon; reads as “toy behind blister”.
class _ToySilhouettePainter extends CustomPainter {
  _ToySilhouettePainter({
    required this.variant,
    required this.seed,
    required this.fill,
    required this.accent,
    required this.isSecret,
    required this.compact,
  });

  final int variant;
  final String seed;
  final Color fill;
  final Color accent;
  final bool isSecret;
  final bool compact;

  double _nudge(int i) => ((seed.hashCode >> (i * 3)) & 0x7) / 120.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final s = compact ? 0.92 : 1.0;
    canvas.save();
    canvas.translate(w * (1 - s) * 0.5, h * (1 - s) * 0.52);
    canvas.scale(s);

    final path = _silhouettePath(w, h, variant);
    canvas.drawPath(
      path,
      Paint()
        ..color = fill
        ..style = PaintingStyle.fill,
    );

    // Tiny “personality” offset eyes — whisper of character, not emoji.
    final ex = w * (0.42 + _nudge(0));
    final ey = h * (0.34 + _nudge(1));
    final er = w * (compact ? 0.022 : 0.028);
    canvas.drawCircle(
      Offset(ex, ey),
      er,
      Paint()..color = accent.withValues(alpha: 0.35),
    );
    canvas.drawCircle(
      Offset(w * (0.58 - _nudge(2)), ey),
      er,
      Paint()..color = accent.withValues(alpha: 0.35),
    );

    if (isSecret && !compact) {
      final arc = Path()
        ..addArc(
          Rect.fromCircle(center: Offset(w * 0.82, h * 0.14), radius: w * 0.11),
          -math.pi * 0.15,
          math.pi * 0.9,
        );
      canvas.drawPath(
        arc,
        Paint()
          ..color = const Color(0xFFE8C547).withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.restore();
  }

  Path _silhouettePath(double w, double h, int v) {
    final n1 = _nudge(3);
    final n2 = _nudge(4);
    final path = Path();
    switch (v % 3) {
      case 0:
        path.addOval(
          Rect.fromCircle(
            center: Offset(w * (0.5 + n1 * 0.3), h * 0.3),
            radius: w * 0.17,
          ),
        );
        path.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.24, h * 0.4, w * 0.52, h * 0.48),
            Radius.circular(w * 0.2),
          ),
        );
        break;
      case 1:
        path.addOval(
          Rect.fromCircle(
            center: Offset(w * 0.5, h * 0.28 + n2),
            radius: w * 0.19,
          ),
        );
        path.addOval(
          Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.62),
            width: w * 0.58,
            height: h * 0.42,
          ),
        );
        break;
      default:
        path.moveTo(w * 0.5, h * 0.1 + n1);
        path.quadraticBezierTo(w * 0.92, h * 0.28, w * 0.86, h * 0.52 + n2);
        path.quadraticBezierTo(w * 0.78, h * 0.92, w * 0.5, h * 0.94);
        path.quadraticBezierTo(w * 0.22, h * 0.92, w * 0.14, h * 0.52 + n2);
        path.quadraticBezierTo(w * 0.08, h * 0.28, w * 0.5, h * 0.1 + n1);
        path.close();
        break;
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _ToySilhouettePainter oldDelegate) =>
      oldDelegate.variant != variant ||
      oldDelegate.seed != seed ||
      oldDelegate.fill != fill ||
      oldDelegate.accent != accent ||
      oldDelegate.isSecret != isSecret ||
      oldDelegate.compact != compact;
}
