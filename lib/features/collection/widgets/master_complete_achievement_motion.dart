import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Soft gold palette for the global Master Complete achievement moment.
abstract final class MasterCompleteAchievementColors {
  MasterCompleteAchievementColors._();

  static const gold = Color(0xFFE8C547);
  static const goldDeep = Color(0xFFC9A227);
  static const goldSoft = Color(0xFFF5E6A8);
  static const goldWarm = Color(0xFFF0D78C);
}

/// Phase envelopes for the achievement overlay (normalized 0–1 over ~950 ms).
abstract final class MasterCompleteAchievementTiming {
  MasterCompleteAchievementTiming._();

  /// Gentle appear — ~110 ms at default duration.
  static const double entranceEnd = 0.115;

  /// Hold before unified fade-out (after crown sparkle sequence).
  static const double exitStart = 0.92;

  static const double scrimPeak = 0.13;
  static const double blurPeakSigma = 5.5;

  static double _safeT(double t) => t.clamp(0.0, 1.0);

  static double _curveT(double t, double start, double span) {
    if (span <= 0) return 0;
    return ((t - start) / span).clamp(0.0, 1.0);
  }

  /// Master fade — drives scrim, blur, and content opacity together.
  static double masterOpacity(double t) {
    t = _safeT(t);
    if (t <= entranceEnd) {
      return Curves.easeOutCubic.transform(t / entranceEnd);
    }
    if (t <= exitStart) return 1;
    return 1 -
        Curves.easeInCubic.transform(_curveT(t, exitStart, 1 - exitStart));
  }

  /// Apple-style settle: 98% → 100% during entrance only.
  static double entranceScale(double t) {
    t = _safeT(t);
    if (t <= entranceEnd) {
      return lerpDouble(
        0.98,
        1,
        Curves.easeOutCubic.transform(t / entranceEnd),
      )!;
    }
    return 1;
  }

  static double scrimOpacity(double t) => scrimPeak * masterOpacity(t);

  static double blurSigma(double t) => blurPeakSigma * masterOpacity(t);

  /// Effect intensity peaks mid-hold, eases with master fade.
  static double effectsIntensity(double t) {
    t = _safeT(t);
    final envelope = masterOpacity(t);
    if (t <= entranceEnd) return envelope * 0.35;
    if (t <= exitStart) {
      final hold = _curveT(t, entranceEnd, exitStart - entranceEnd);
      return envelope * (0.55 + 0.45 * Curves.easeOut.transform(hold));
    }
    return envelope;
  }
}

/// One brief diamond reflection near the crown — never overlaps siblings.
class CrownDiamondSparkle {
  const CrownDiamondSparkle({
    required this.id,
    required this.offsetFromCrown,
    required this.start,
    required this.span,
    required this.size,
    required this.style,
  });

  final int id;

  /// Normalized offset from crown anchor in the effect canvas.
  final Offset offsetFromCrown;

  /// Normalized timeline start / duration (0–1 over overlay length).
  final double start;
  final double span;
  final double size;
  final CrownSparkleStyle style;

  double get end => start + span;

  bool isActiveAt(double progress) =>
      progress >= start && progress < end;

  /// Local 0–1 progress while this sparkle is alive.
  double localProgress(double progress) {
    if (!isActiveAt(progress)) return -1;
    return ((progress - start) / span).clamp(0.0, 1.0);
  }
}

enum CrownSparkleStyle { fourPoint, softCross }

/// Sequential crown shimmer — one glint at a time, jewelry-ad style.
abstract final class MasterCompleteCrownSparkleSequence {
  MasterCompleteCrownSparkleSequence._();

  /// Crown anchor in the 280×240 effect canvas (emoji center).
  static const crownAnchor = Offset(0.5, 0.36);

  /// ~760 ms of staggered glints after entrance; windows do not overlap.
  static const sparkles = <CrownDiamondSparkle>[
    CrownDiamondSparkle(
      id: 0,
      offsetFromCrown: Offset(-0.1, -0.14),
      start: 0.13,
      span: 0.158,
      size: 2.8,
      style: CrownSparkleStyle.fourPoint,
    ),
    CrownDiamondSparkle(
      id: 1,
      offsetFromCrown: Offset(0.13, -0.04),
      start: 0.31,
      span: 0.189,
      size: 3.2,
      style: CrownSparkleStyle.softCross,
    ),
    CrownDiamondSparkle(
      id: 2,
      offsetFromCrown: Offset(-0.12, 0.1),
      start: 0.515,
      span: 0.168,
      size: 2.6,
      style: CrownSparkleStyle.fourPoint,
    ),
    CrownDiamondSparkle(
      id: 3,
      offsetFromCrown: Offset(0.02, -0.2),
      start: 0.698,
      span: 0.142,
      size: 2.4,
      style: CrownSparkleStyle.softCross,
    ),
    CrownDiamondSparkle(
      id: 4,
      offsetFromCrown: Offset(0.11, 0.06),
      start: 0.855,
      span: 0.126,
      size: 2.2,
      style: CrownSparkleStyle.fourPoint,
    ),
  ];

  static List<CrownDiamondSparkle> activeAt(double progress) {
    return [
      for (final s in sparkles)
        if (s.isActiveAt(progress)) s,
    ];
  }

  /// Fade in → brighten → scale 1.0→1.15 → fade out.
  @visibleForTesting
  static double sparkleOpacity(double localT) {
    final t = localT.clamp(0.0, 1.0);
    if (t <= 0.22) {
      return Curves.easeOut.transform(t / 0.22) * 0.55;
    }
    if (t <= 0.42) {
      final p = (t - 0.22) / 0.2;
      return 0.55 + Curves.easeOut.transform(p) * 0.45;
    }
    if (t <= 0.72) return 1 - Curves.easeIn.transform((t - 0.42) / 0.3) * 0.35;
    return (1 - Curves.easeInCubic.transform((t - 0.72) / 0.28)).clamp(0.0, 1.0) * 0.65;
  }

  @visibleForTesting
  static double sparkleScale(double localT) {
    final t = localT.clamp(0.0, 1.0);
    if (t <= 0.48) {
      return lerpDouble(1, 1.15, Curves.easeOutCubic.transform(t / 0.48))!;
    }
    return lerpDouble(
      1.15,
      1,
      Curves.easeIn.transform(((t - 0.48) / 0.52).clamp(0.0, 1.0)),
    )!;
  }
}

/// Soft radial glow + sequential crown diamond sparkles — one paint pass.
class MasterCompleteAchievementEffectsPainter extends CustomPainter {
  const MasterCompleteAchievementEffectsPainter({
    required this.progress,
    required this.intensity,
  });

  final double progress;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1 || intensity <= 0.01) return;

    _paintRadialGlow(canvas, size);

    final crown = Offset(
      MasterCompleteCrownSparkleSequence.crownAnchor.dx * size.width,
      MasterCompleteCrownSparkleSequence.crownAnchor.dy * size.height,
    );

    for (final sparkle in MasterCompleteCrownSparkleSequence.activeAt(progress)) {
      final localT = sparkle.localProgress(progress);
      if (localT < 0) continue;

      final alpha =
          (MasterCompleteCrownSparkleSequence.sparkleOpacity(localT) *
                  intensity)
              .clamp(0.0, 1.0);
      if (alpha <= 0.02) continue;

      final scale = MasterCompleteCrownSparkleSequence.sparkleScale(localT);
      final center = crown + Offset(
        sparkle.offsetFromCrown.dx * size.width,
        sparkle.offsetFromCrown.dy * size.height,
      );

      _paintDiamondReflection(
        canvas,
        center,
        size: sparkle.size,
        opacity: alpha,
        scale: scale,
        style: sparkle.style,
      );
    }
  }

  void _paintRadialGlow(Canvas canvas, Size size) {
    final center = Offset(
      MasterCompleteCrownSparkleSequence.crownAnchor.dx * size.width,
      MasterCompleteCrownSparkleSequence.crownAnchor.dy * size.height,
    );
    const radius = 118.0;
    final strength = intensity.clamp(0.0, 1.0);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1,
        colors: [
          MasterCompleteAchievementColors.goldWarm.withValues(
            alpha: 0.18 * strength,
          ),
          MasterCompleteAchievementColors.goldSoft.withValues(
            alpha: 0.08 * strength,
          ),
          MasterCompleteAchievementColors.gold.withValues(
            alpha: 0.022 * strength,
          ),
          Colors.transparent,
        ],
        stops: const [0.0, 0.32, 0.58, 1.0],
      ).createShader(rect);
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _paintDiamondReflection(
    Canvas canvas,
    Offset center, {
    required double size,
    required double opacity,
    required double scale,
    required CrownSparkleStyle style,
  }) {
    final arm = size * scale;
    final haloR = arm * 1.65;

    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: opacity * 0.92),
          Color.lerp(
            Colors.white,
            MasterCompleteAchievementColors.goldSoft,
            0.08,
          )!.withValues(alpha: opacity * 0.55),
          MasterCompleteAchievementColors.goldSoft.withValues(
            alpha: opacity * 0.12,
          ),
          Colors.transparent,
        ],
        stops: const [0.0, 0.38, 0.68, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: haloR));
    canvas.drawCircle(center, haloR, haloPaint);

    final stroke = Paint()
      ..strokeWidth = style == CrownSparkleStyle.fourPoint ? 0.7 : 0.55
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: opacity * 0.88);

    canvas.drawLine(
      Offset(center.dx - arm, center.dy),
      Offset(center.dx + arm, center.dy),
      stroke,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - arm),
      Offset(center.dx, center.dy + arm),
      stroke,
    );

    if (style == CrownSparkleStyle.fourPoint) {
      final d = arm * 0.58;
      final diag = Paint()
        ..strokeWidth = 0.45
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(
          Colors.white,
          MasterCompleteAchievementColors.goldWarm,
          0.07,
        )!.withValues(alpha: opacity * 0.62);
      canvas.drawLine(
        Offset(center.dx - d, center.dy - d),
        Offset(center.dx + d, center.dy + d),
        diag,
      );
      canvas.drawLine(
        Offset(center.dx + d, center.dy - d),
        Offset(center.dx - d, center.dy + d),
        diag,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MasterCompleteAchievementEffectsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity;
  }
}
