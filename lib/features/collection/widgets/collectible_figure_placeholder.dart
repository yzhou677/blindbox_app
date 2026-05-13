import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Cozy shelf-style art when there is no photo — still feels like a tiny collectible.
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
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final w = parts[0];
      if (w.length >= 2) return w.substring(0, 2).toUpperCase();
      return w[0].toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static (Color light, Color deep) _pastelPair(String seed) {
    final h = seed.hashCode.abs() % 360;
    final light = HSLColor.fromAHSL(1, h.toDouble(), 0.38, 0.93).toColor();
    final deep = HSLColor.fromAHSL(1, (h + 18) % 360.0, 0.45, 0.72).toColor();
    return (light, deep);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (light, deep) = _pastelPair(seedKey);
    final initials = initialsFor(name);
    final iconSize = compact ? 22.0 : 34.0;
    final letterStyle = (compact ? textTheme.titleSmall : textTheme.titleLarge)?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: compact ? -0.2 : -0.4,
      color: deep.withValues(alpha: 0.88),
      height: 1,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 10 : 14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(light, scheme.surface, 0.12)!,
                Color.lerp(deep, light, 0.35)!,
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _SoftShelfGloss(compact: compact),
          ),
        ),
        Center(
          child: Icon(
            Icons.toys_rounded,
            size: iconSize,
            color: deep.withValues(alpha: 0.14),
          ),
        ),
        Center(
          child: Text(
            initials,
            style: letterStyle,
          ),
        ),
        if (isSecret && !compact)
          Positioned(
            bottom: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 12, color: deep.withValues(alpha: 0.55)),
                const SizedBox(width: 2),
                Text(
                  'chase',
                  style: textTheme.labelSmall?.copyWith(
                    color: deep.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SoftShelfGloss extends CustomPainter {
  _SoftShelfGloss({required this.compact});

  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(compact ? 10 : 14),
    );
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.2, 0),
        Offset(size.width * 0.85, size.height),
        [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0),
        ],
      );
    canvas.drawRRect(r, paint);
  }

  @override
  bool shouldRepaint(covariant _SoftShelfGloss oldDelegate) => oldDelegate.compact != compact;
}
