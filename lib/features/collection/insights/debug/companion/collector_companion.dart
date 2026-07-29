import 'dart:async';
import 'dart:math' as math;

import 'package:blindbox_app/features/collection/insights/debug/companion/collector_companion_assets.dart';
import 'package:blindbox_app/features/collection/insights/debug/companion/companion_reaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Micro-adjustment only:
/// - trophy at original size
/// - trophy translated down alone (lap / lower-torso prop)
/// - arms/hands stay put
const double _kTrophyScale = 1.0;
const double _kArmsRestOffsetY = 10;
const double _kTrophyRestOffsetY = 54;

/// Reusable layered Collector Companion for motion prototyping.
class CollectorCompanion extends StatefulWidget {
  const CollectorCompanion({
    super.key,
    required this.assets,
    this.reaction = CompanionReaction.idle,
    this.size = 280,
    this.motionSpeed = 1.0,
    this.floatAmount = 1.0,
    this.headRotationAmount = 1.0,
    this.breathingAmount = 1.0,
    this.sparkleIntensity = 1.0,
    this.animationDurationScale = 1.0,
    this.loopIdle = true,
    this.idleLife = true,
    this.onReactionCompleted,
  });

  final CollectorCompanionAssets assets;
  final CompanionReaction reaction;
  final double size;
  final double motionSpeed;
  final double floatAmount;
  final double headRotationAmount;
  final double breathingAmount;
  final double sparkleIntensity;
  final double animationDurationScale;
  final bool loopIdle;
  final bool idleLife;
  final ValueChanged<CompanionReaction>? onReactionCompleted;

  @override
  State<CollectorCompanion> createState() => CollectorCompanionState();
}

class CollectorCompanionState extends State<CollectorCompanion>
    with TickerProviderStateMixin {
  late final AnimationController _breath;
  late final AnimationController _float;
  late final AnimationController _headWander;
  late final AnimationController _idleGesture;
  late final AnimationController _reaction;

  late Animation<double> _breathScale;
  late Animation<double> _floatY;

  CompanionReaction _active = CompanionReaction.idle;
  Timer? _headPauseTimer;
  Timer? _idleLifeTimer;
  final math.Random _rng = math.Random();

  double _headWanderAngle = 0;
  double _headWanderFrom = 0;
  double _headWanderTo = 0;

  double _bodyNudgeY = 0;
  double _bodyNudgeScale = 1;
  double _headRot = 0;
  double _headNudgeX = 0;
  double _headNudgeY = 0;
  double _crownExtraY = 0;
  double _armsY = 0;
  double _armsScale = 1;
  double _armsRot = 0;
  double _glow = 0;
  double _rootOpacity = 1;
  double _rootScale = 1;
  double _sparkleT = 0;
  double _thinkMark = 0;
  bool _showQuestion = false;

  /// 0 = satisfied nod only (no arm re-pose).
  int _idleGestureKind = 0;

  Listenable get _tick => Listenable.merge(<Listenable>[
        _breath,
        _float,
        _headWander,
        _idleGesture,
        _reaction,
      ]);

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(vsync: this);
    _float = AnimationController(vsync: this);
    _headWander = AnimationController(vsync: this);
    _idleGesture = AnimationController(vsync: this);
    _reaction = AnimationController(vsync: this);
    _wireCurves();
    _configureIdleDurations();
    _headWander.addStatusListener(_onHeadWanderStatus);
    _idleGesture.addStatusListener(_onIdleGestureStatus);
    _reaction.addStatusListener(_onReactionStatus);
    if (widget.loopIdle) {
      _breath.repeat(reverse: true);
      _float.repeat(reverse: true);
    }
    _startHeadWanderCycle();
    _scheduleIdleLife();
    if (widget.reaction != CompanionReaction.idle) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) playReaction(widget.reaction);
      });
    }
  }

  @override
  void didUpdateWidget(covariant CollectorCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.motionSpeed != widget.motionSpeed ||
        oldWidget.animationDurationScale != widget.animationDurationScale) {
      _configureIdleDurations();
    }
    if (oldWidget.loopIdle != widget.loopIdle) {
      if (widget.loopIdle) {
        _breath.repeat(reverse: true);
        _float.repeat(reverse: true);
      } else {
        _breath.stop();
        _float.stop();
      }
    }
    if (oldWidget.idleLife != widget.idleLife) {
      if (widget.idleLife) {
        _scheduleIdleLife();
      } else {
        _idleLifeTimer?.cancel();
      }
    }
    if (oldWidget.reaction != widget.reaction) {
      playReaction(widget.reaction);
    }
  }

  @override
  void dispose() {
    _headPauseTimer?.cancel();
    _idleLifeTimer?.cancel();
    _headWander.removeStatusListener(_onHeadWanderStatus);
    _idleGesture.removeStatusListener(_onIdleGestureStatus);
    _reaction.removeStatusListener(_onReactionStatus);
    _breath.dispose();
    _float.dispose();
    _headWander.dispose();
    _idleGesture.dispose();
    _reaction.dispose();
    super.dispose();
  }

  void playReaction(CompanionReaction reaction) {
    _active = reaction;
    _resetReactionPose();
    _idleLifeTimer?.cancel();
    _idleGesture.stop();
    _idleGesture.value = 0;

    if (reaction == CompanionReaction.idle) {
      _reaction.stop();
      _reaction.value = 0;
      if (widget.loopIdle && !_breath.isAnimating) {
        _breath.repeat(reverse: true);
        _float.repeat(reverse: true);
      }
      if (mounted) setState(() {});
      _scheduleIdleLife();
      return;
    }

    _reaction.duration = _reactionDuration(reaction);
    _reaction.forward(from: 0);
    if (mounted) setState(() {});
  }

  void resetToIdle() => playReaction(CompanionReaction.idle);

  CompanionReaction get activeReaction => _active;

  void _wireCurves() {
    _breathScale = Tween<double>(begin: 0.9916, end: 1.0084).animate(
      CurvedAnimation(parent: _breath, curve: Curves.easeInOutSine),
    );
    _floatY = Tween<double>(begin: 2.2, end: -2.2).animate(
      CurvedAnimation(parent: _float, curve: Curves.easeInOutSine),
    );
  }

  void _configureIdleDurations() {
    final speed = widget.motionSpeed.clamp(0.35, 2.5);
    final scale = widget.animationDurationScale.clamp(0.4, 2.5);
    final breathWas = _breath.isAnimating;
    final floatWas = _float.isAnimating;
    _breath.duration = Duration(milliseconds: (3400 / speed * scale).round());
    _float.duration = Duration(milliseconds: (5200 / speed * scale).round());
    if (breathWas) _breath.repeat(reverse: true);
    if (floatWas) _float.repeat(reverse: true);
  }

  Duration _reactionDuration(CompanionReaction reaction) {
    final speed = widget.motionSpeed.clamp(0.35, 2.5);
    final scale = widget.animationDurationScale.clamp(0.4, 2.5);
    final ms = switch (reaction) {
      CompanionReaction.idle => 0,
      CompanionReaction.happy => 900,
      CompanionReaction.celebrate => 1600,
      CompanionReaction.thinking => 2200,
      CompanionReaction.newRevealAvailable => 1800,
      CompanionReaction.typeChanged => 1100,
      CompanionReaction.sameType => 800,
    };
    return Duration(milliseconds: (ms / speed * scale).round());
  }

  void _onReactionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final done = _active;
    if (done == CompanionReaction.idle) return;
    _finishReaction(done);
  }

  void _finishReaction(CompanionReaction done) {
    _resetReactionPose();
    _active = CompanionReaction.idle;
    _reaction.value = 0;
    widget.onReactionCompleted?.call(done);
    if (mounted) setState(() {});
    _scheduleIdleLife();
  }

  void _resetReactionPose() {
    _bodyNudgeY = 0;
    _bodyNudgeScale = 1;
    _headRot = 0;
    _headNudgeX = 0;
    _headNudgeY = 0;
    _crownExtraY = 0;
    _armsY = 0;
    _armsScale = 1;
    _armsRot = 0;
    _glow = 0;
    _rootOpacity = 1;
    _rootScale = 1;
    _sparkleT = 0;
    _thinkMark = 0;
    _showQuestion = false;
  }

  void _startHeadWanderCycle() {
    if (!mounted || !widget.loopIdle) return;
    _headPauseTimer?.cancel();
    _headWanderFrom = _headWanderAngle;
    final magnitude = 0.012 + _rng.nextDouble() * 0.018;
    final double target;
    if (_headWanderFrom.abs() > 0.008 && _rng.nextDouble() < 0.7) {
      target = -_headWanderFrom.sign * magnitude;
    } else if (_rng.nextDouble() < 0.25) {
      target = (_rng.nextBool() ? 1.0 : -1.0) * magnitude * 0.35;
    } else {
      target = (_rng.nextBool() ? 1.0 : -1.0) * magnitude;
    }
    _headWanderTo = target;
    final speed = widget.motionSpeed.clamp(0.35, 2.5);
    final scale = widget.animationDurationScale.clamp(0.4, 2.5);
    final moveMs =
        ((900 + _rng.nextInt(1100)) / speed * scale).round().clamp(500, 2800);
    _headWander.duration = Duration(milliseconds: moveMs);
    _headWander.forward(from: 0);
  }

  void _onHeadWanderStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _headWanderAngle = _headWanderTo;
    _headPauseTimer?.cancel();
    _headPauseTimer = Timer(Duration(milliseconds: 700 + _rng.nextInt(2800)), () {
      if (!mounted) return;
      if (_active != CompanionReaction.idle) {
        _headPauseTimer = Timer(const Duration(milliseconds: 600), () {
          if (mounted) _startHeadWanderCycle();
        });
        return;
      }
      _startHeadWanderCycle();
    });
  }

  double get _headWanderAnimated {
    if (!_headWander.isAnimating) return _headWanderAngle;
    final t = Curves.easeInOutCubic.transform(_headWander.value);
    return uiLerp(_headWanderFrom, _headWanderTo, t);
  }

  void _scheduleIdleLife() {
    _idleLifeTimer?.cancel();
    if (!widget.idleLife || !mounted) return;
    _idleLifeTimer = Timer(
      Duration(milliseconds: 12000 + _rng.nextInt(8000)),
      () {
        if (!mounted || _active != CompanionReaction.idle) {
          _scheduleIdleLife();
          return;
        }
        if (_idleGesture.isAnimating) {
          _scheduleIdleLife();
          return;
        }
        _idleGestureKind = 0; // nod only — never re-pose arms
        final speed = widget.motionSpeed.clamp(0.35, 2.5);
        final scale = widget.animationDurationScale.clamp(0.4, 2.5);
        _idleGesture.duration = Duration(
          milliseconds: (720 / speed * scale).round(),
        );
        _idleGesture.forward(from: 0);
      },
    );
  }

  void _onIdleGestureStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _idleGesture.value = 0;
    _scheduleIdleLife();
  }

  void _sampleIdleGesture(double t) {
    final wave = math.sin(t * math.pi);
    _headNudgeY = wave * 3.2;
    _headRot = wave * 0.012;
    _crownExtraY = wave * 1.2;
  }

  void _sampleReaction(double t) {
    final curved = Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));
    switch (_active) {
      case CompanionReaction.idle:
        break;
      case CompanionReaction.happy:
        final bounce = math.sin(t * math.pi);
        _bodyNudgeY = -bounce * 7 * widget.floatAmount;
        _bodyNudgeScale = 1 + bounce * 0.03 * widget.breathingAmount;
        _headNudgeY = -bounce * 3;
        _sparkleT = bounce * widget.sparkleIntensity;
      case CompanionReaction.celebrate:
        // Raise the existing arms_trophy unit (no re-pose of hands/sleeves).
        final lift = math.sin(t * math.pi);
        _armsY = -lift * 28;
        _armsScale = 1 + lift * 0.05;
        _bodyNudgeY = -lift * 5 * widget.floatAmount;
        _bodyNudgeScale = 1 + lift * 0.025;
        _headNudgeY = -lift * 3;
        _crownExtraY = -lift * 4;
        _sparkleT = lift * widget.sparkleIntensity;
      case CompanionReaction.thinking:
        _headRot = curved * 0.08 * widget.headRotationAmount;
        _headNudgeX = curved * 3;
        _showQuestion = t > 0.12 && t < 0.92;
        _thinkMark = math.sin((t - 0.12).clamp(0.0, 1.0) * math.pi);
      case CompanionReaction.newRevealAvailable:
        _glow = math.sin(t * math.pi) * 0.55;
        _sparkleT = math.sin(t * math.pi) * 0.7 * widget.sparkleIntensity;
        _headNudgeY = -math.sin(t * math.pi) * 1.5;
      case CompanionReaction.typeChanged:
        if (t < 0.45) {
          final u = t / 0.45;
          _rootOpacity = 1 - u;
          _rootScale = 1 - u * 0.06;
        } else {
          final u = (t - 0.45) / 0.55;
          _rootOpacity = u;
          _rootScale = 0.94 + u * 0.06;
        }
        _sparkleT = math.sin(t * math.pi) * 0.4 * widget.sparkleIntensity;
      case CompanionReaction.sameType:
        final nod = math.sin(t * math.pi);
        _headNudgeY = nod * 4;
        _headRot = nod * 0.02;
        _sparkleT = nod * 0.55 * widget.sparkleIntensity;
        _bodyNudgeY = -nod * 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _tick,
        builder: (context, _) {
          _resetReactionPose();
          if (_active == CompanionReaction.idle) {
            if (_idleGesture.isAnimating || _idleGesture.value > 0) {
              _sampleIdleGesture(_idleGesture.value);
            }
          } else {
            _sampleReaction(_reaction.value);
          }

          final breath =
              1 + (_breathScale.value - 1) * widget.breathingAmount;
          final float = _floatY.value * widget.floatAmount + _bodyNudgeY;
          final headWander = _headWanderAnimated;
          final headSway = headWander * widget.headRotationAmount + _headRot;
          final double crownWander;
          if (_headWander.isAnimating) {
            final lagged = (_headWander.value - 0.07).clamp(0.0, 1.0);
            crownWander = uiLerp(
                  _headWanderFrom,
                  _headWanderTo,
                  Curves.easeInOutCubic.transform(lagged),
                ) *
                widget.headRotationAmount;
          } else {
            crownWander = headWander * widget.headRotationAmount;
          }

          return Opacity(
            opacity: _rootOpacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: _rootScale,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_glow > 0.01)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFB8C9A8)
                                  .withValues(alpha: 0.35 * _glow),
                              blurRadius: 28 + 20 * _glow,
                              spreadRadius: 4 * _glow,
                            ),
                          ],
                        ),
                      ),
                    Transform.translate(
                      offset: Offset(0, float),
                      child: Transform.scale(
                        scale: breath * _bodyNudgeScale,
                        alignment: Alignment.bottomCenter,
                        child: _layer(widget.assets.body),
                      ),
                    ),
                    // Same composition as the approved illustration:
                    // head under arms_trophy so the cup can kiss the chin.
                    Transform.translate(
                      offset: Offset(_headNudgeX, float + _headNudgeY),
                      child: Transform.rotate(
                        angle: headSway,
                        alignment: const Alignment(0, 0.35),
                        child: _layer(widget.assets.head),
                      ),
                    ),
                    // Trophy under arms (fingers in front). Trophy only moves down.
                    Transform.translate(
                      offset: Offset(0, float + _kTrophyRestOffsetY + _armsY),
                      child: Transform.rotate(
                        angle: _armsRot,
                        child: Transform.scale(
                          scale: _kTrophyScale * _armsScale,
                          alignment: Alignment.center,
                          child: _layer(widget.assets.trophy),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, float + _kArmsRestOffsetY + _armsY),
                      child: Transform.rotate(
                        angle: _armsRot,
                        child: _layer(widget.assets.arms),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(
                        _headNudgeX * 0.85,
                        float + _headNudgeY + _crownExtraY,
                      ),
                      child: Transform.rotate(
                        angle: crownWander + _headRot * 0.7,
                        alignment: const Alignment(0, 0.55),
                        child: _layer(widget.assets.crown),
                      ),
                    ),
                    if (_sparkleT > 0.02)
                      CustomPaint(
                        painter: _CompanionSparklePainter(
                          progress: _sparkleT,
                          intensity: widget.sparkleIntensity,
                        ),
                      ),
                    if (_showQuestion && _thinkMark > 0.05)
                      Align(
                        alignment: const Alignment(0.42, -0.62),
                        child: Opacity(
                          opacity: _thinkMark.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, -6 * _thinkMark),
                            child: Text(
                              '?',
                              style: TextStyle(
                                fontSize: widget.size * 0.12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF6B7A62)
                                    .withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _layer(String asset) {
    return Image.asset(
      asset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );
  }
}

double uiLerp(double a, double b, double t) => a + (b - a) * t;

class _CompanionSparklePainter extends CustomPainter {
  _CompanionSparklePainter({
    required this.progress,
    required this.intensity,
  });

  final double progress;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.42;
    final paint = Paint()..style = PaintingStyle.fill;
    const n = 7;
    for (var i = 0; i < n; i++) {
      final a = (i / n) * math.pi * 2 + progress * 1.2;
      final r =
          size.width * (0.18 + 0.12 * progress) * (0.7 + 0.3 * intensity);
      final x = cx + math.cos(a) * r;
      final y = cy + math.sin(a) * r * 0.75 - progress * 10;
      final s = (3.0 + (i % 3)) * progress * intensity;
      paint.color = Color.lerp(
        const Color(0xFFE8D9A8),
        const Color(0xFFC5D4B5),
        i / n,
      )!.withValues(alpha: 0.75 * progress);
      _drawStar(canvas, Offset(x, y), s, paint);
    }
  }

  void _drawStar(Canvas canvas, Offset c, double radius, Paint paint) {
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final a = -math.pi / 2 + i * math.pi / 2;
      final p = Offset(
        c.dx + math.cos(a) * radius,
        c.dy + math.sin(a) * radius,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
      final a2 = a + math.pi / 4;
      final p2 = Offset(
        c.dx + math.cos(a2) * radius * 0.35,
        c.dy + math.sin(a2) * radius * 0.35,
      );
      path.lineTo(p2.dx, p2.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CompanionSparklePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity;
  }
}
