import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Golden palette for Master Complete micro-celebrations.
abstract final class MasterCompleteCelebrationColors {
  MasterCompleteCelebrationColors._();

  static const gold = Color(0xFFE8C547);
  static const goldDeep = Color(0xFFC9A227);
  static const goldSoft = Color(0xFFF5E6A8);
}

/// Opacity hump for the ambient 👑·✨ blink (0 → peak → 0).
@visibleForTesting
double masterCompleteAmbientSparkleOpacity(double t) {
  if (t <= 0 || t >= 1) return 0;
  return math.sin(t * math.pi) * 0.46;
}

/// Badge + earn celebration + occasional ambient blink on sustained master rows.
///
/// Drive [celebrateTick] from a parent that detects `false → true` transitions.
/// The tick must **not** increment on cold start when the series is already master
/// complete — only on live transitions (including re-earning after a loss).
///
/// [ambientStaggerSeed] spreads ~20s ambient blinks across cards (typically series id).
/// No user setting — earn burst is ~1s once; ambient is one soft blink per interval.
class MasterCompleteCelebrationBadge extends StatefulWidget {
  const MasterCompleteCelebrationBadge({
    super.key,
    required this.isMasterComplete,
    required this.celebrateTick,
    required this.textStyle,
    required this.ambientStaggerSeed,
    this.fallback,
  });

  final bool isMasterComplete;
  final int celebrateTick;
  final TextStyle textStyle;

  /// Stagger ambient timer phase — e.g. shelf series id.
  final String ambientStaggerSeed;
  final Widget? fallback;

  @override
  State<MasterCompleteCelebrationBadge> createState() =>
      _MasterCompleteCelebrationBadgeState();
}

class _MasterCompleteCelebrationBadgeState
    extends State<MasterCompleteCelebrationBadge>
    with TickerProviderStateMixin {
  late AnimationController _celebration;
  late AnimationController _ambientBlink;
  Timer? _ambientInitial;
  Timer? _ambientPeriodic;

  @override
  void initState() {
    super.initState();
    _celebration = AnimationController(
      vsync: this,
      duration: CollectibleMotion.masterCompleteCelebration,
    );
    _ambientBlink = AnimationController(
      vsync: this,
      duration: CollectibleMotion.masterCompleteAmbientBlink,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncAmbientSchedule();
    });
  }

  @override
  void didUpdateWidget(MasterCompleteCelebrationBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.celebrateTick > oldWidget.celebrateTick) {
      _startCelebration();
    }
    if (widget.isMasterComplete != oldWidget.isMasterComplete ||
        widget.ambientStaggerSeed != oldWidget.ambientStaggerSeed) {
      _syncAmbientSchedule();
    }
  }

  void _startCelebration() {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    HapticFeedback.lightImpact();
    _celebration.forward(from: 0);
  }

  void _syncAmbientSchedule() {
    _cancelAmbientTimers();
    if (!widget.isMasterComplete || !mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) return;

    final phaseMs = widget.ambientStaggerSeed.hashCode.abs() %
        CollectibleMotion.masterCompleteAmbientInterval.inMilliseconds;

    _ambientInitial = Timer(Duration(milliseconds: phaseMs), () {
      if (!mounted) return;
      _pulseAmbient();
      _ambientPeriodic = Timer.periodic(
        CollectibleMotion.masterCompleteAmbientInterval,
        (_) {
          if (mounted) _pulseAmbient();
        },
      );
    });
  }

  void _pulseAmbient() {
    if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
    if (_celebration.isAnimating) return;
    _ambientBlink.forward(from: 0);
  }

  void _cancelAmbientTimers() {
    _ambientInitial?.cancel();
    _ambientInitial = null;
    _ambientPeriodic?.cancel();
    _ambientPeriodic = null;
  }

  @override
  void dispose() {
    _cancelAmbientTimers();
    _celebration.dispose();
    _ambientBlink.dispose();
    super.dispose();
  }

  static double _badgeScale(double t) {
    if (t <= 0.35) {
      final p = Curves.easeOutCubic.transform(t / 0.35);
      return lerpDouble(1, CollectibleMotion.masterCompleteBadgeScalePeak, p)!;
    }
    if (t <= 0.58) {
      final p = Curves.easeInOutCubic.transform((t - 0.35) / 0.23);
      return lerpDouble(CollectibleMotion.masterCompleteBadgeScalePeak, 1, p)!;
    }
    return 1;
  }

  static double _glowOpacity(double t) {
    if (t <= 0.14) return Curves.easeOut.transform(t / 0.14) * 0.16;
    if (t <= 0.58) {
      return 0.16 * (1 - Curves.easeInCubic.transform((t - 0.14) / 0.44));
    }
    return 0;
  }

  Widget _buildBadge({required double ambientT}) {
    final sparkle = masterCompleteAmbientSparkleOpacity(ambientT);
    final baseStyle = widget.textStyle;
    final children = <InlineSpan>[
      const TextSpan(text: '👑'),
      if (sparkle > 0.02)
        TextSpan(
          text: ' · ✨',
          style: baseStyle.copyWith(
            fontSize: (baseStyle.fontSize ?? 14) * 0.88,
            color: baseStyle.color?.withValues(alpha: sparkle),
            letterSpacing: 0.02,
          ),
        ),
      const TextSpan(text: ' ${CollectionVocabulary.masterComplete}'),
    ];

    return Semantics(
      label: CollectionVocabulary.masterComplete,
      child: Text.rich(TextSpan(style: baseStyle, children: children)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isMasterComplete) {
      return widget.fallback ?? const SizedBox.shrink();
    }

    if (MediaQuery.disableAnimationsOf(context)) {
      return _buildBadge(ambientT: 0);
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_celebration, _ambientBlink]),
        builder: (context, child) {
          final t = _celebration.value;
          final animating = t > 0 && t < 1;
          final scale = animating ? _badgeScale(t) : 1.0;
          final glow = animating ? _glowOpacity(t) : 0.0;
          final badge = _buildBadge(ambientT: _ambientBlink.value);

          final badgeLayer = Transform.scale(
            scale: scale,
            alignment: Alignment.bottomLeft,
            child: glow > 0.01
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: MasterCompleteCelebrationColors.gold
                              .withValues(alpha: glow),
                          blurRadius: 22 + 6 * glow,
                          spreadRadius: -5,
                        ),
                      ],
                    ),
                    child: badge,
                  )
                : badge,
          );

          if (!animating) return badgeLayer;

          return SizedBox(
            height: 52,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomLeft,
              children: [
                Positioned(
                  left: -8,
                  right: -8,
                  bottom: -4,
                  top: -28,
                  child: CustomPaint(
                    key: const Key('master_complete_celebration_particles'),
                    painter: _MasterCompleteParticlePainter(progress: t),
                  ),
                ),
                badgeLayer,
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Exactly three upward trails; each trail ends in one soft sparkle — never a burst grid.
class _MasterCompleteParticlePainter extends CustomPainter {
  const _MasterCompleteParticlePainter({required this.progress});

  final double progress;

  static const _trailCount = 3;
  static const _trailOrigins = <Offset>[
    Offset(0.28, 1),
    Offset(0.52, 1),
    Offset(0.76, 1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    for (var i = 0; i < _trailCount; i++) {
      _paintTrail(canvas, size, i, _trailOrigins[i]);
    }
  }

  void _paintTrail(Canvas canvas, Size size, int index, Offset originNorm) {
    final stagger = index * 0.05;
    final localT = ((progress - stagger) / (1 - stagger)).clamp(0.0, 1.0);
    if (localT <= 0) return;

    final origin = Offset(
      originNorm.dx * size.width,
      originNorm.dy * size.height,
    );
    const rise = 30.0;
    const launchEnd = 0.5;

    if (localT <= launchEnd) {
      final p = Curves.easeOutCubic.transform(localT / launchEnd);
      final y = origin.dy - rise * p;
      final trailPaint = Paint()
        ..color = MasterCompleteCelebrationColors.goldSoft.withValues(
          alpha: 0.32 * (1 - p * 0.4),
        )
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(origin.dx, origin.dy - 1),
        Offset(origin.dx, y),
        trailPaint,
      );
      final headPaint = Paint()
        ..color = MasterCompleteCelebrationColors.gold.withValues(
          alpha: 0.45 * (1 - p * 0.25),
        );
      canvas.drawCircle(Offset(origin.dx, y), 1.6, headPaint);
      return;
    }

    final burstT = ((localT - launchEnd) / (1 - launchEnd)).clamp(0.0, 1.0);
    if (burstT <= 0) return;

    final apex = Offset(origin.dx, origin.dy - rise - 2);
    final fade = (1 - Curves.easeInCubic.transform(burstT)).clamp(0.0, 1.0);
    _drawSingleSparkle(
      canvas,
      apex,
      size: 2.0 + burstT * 0.8,
      opacity: (0.38 * fade).clamp(0.0, 1.0),
    );
  }

  void _drawSingleSparkle(
    Canvas canvas,
    Offset center, {
    required double size,
    required double opacity,
  }) {
    if (opacity <= 0.01) return;
    final paint = Paint()
      ..color = MasterCompleteCelebrationColors.goldSoft.withValues(
        alpha: opacity,
      )
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx - size, center.dy),
      Offset(center.dx + size, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - size),
      Offset(center.dx, center.dy + size),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MasterCompleteParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
