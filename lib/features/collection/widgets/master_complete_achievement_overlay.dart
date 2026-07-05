import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/master_complete_achievement_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

export 'master_complete_achievement_motion.dart';

/// Full-screen achievement overlay — centered, premium, ~0.95s.
class MasterCompleteAchievementOverlay extends StatefulWidget {
  const MasterCompleteAchievementOverlay({
    super.key,
    required this.onFinished,
  });

  final VoidCallback onFinished;

  @override
  State<MasterCompleteAchievementOverlay> createState() =>
      _MasterCompleteAchievementOverlayState();
}

class _MasterCompleteAchievementOverlayState
    extends State<MasterCompleteAchievementOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  var _started = false;
  ImageFilter? _cachedBlurFilter;
  double _cachedBlurSigma = -1;

  ImageFilter _blurFilterFor(double sigma) {
    final quantized = (sigma * 4).round() / 4.0;
    if (_cachedBlurFilter != null && _cachedBlurSigma == quantized) {
      return _cachedBlurFilter!;
    }
    _cachedBlurSigma = quantized;
    _cachedBlurFilter = ImageFilter.blur(
      sigmaX: quantized,
      sigmaY: quantized,
    );
    return _cachedBlurFilter!;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CollectibleMotion.masterCompleteAchievementOverlay,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _beginPlayback();
    });
  }

  void _beginPlayback() {
    if (_started || !mounted) return;
    _started = true;

    if (MediaQuery.disableAnimationsOf(context)) {
      widget.onFinished();
      return;
    }

    HapticFeedback.lightImpact();
    _controller.addStatusListener(_onAnimationStatus);
    unawaited(_controller.forward(from: 0));
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    _controller.removeStatusListener(_onAnimationStatus);
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: const _AchievementLabel(
          key: Key('master_complete_achievement_label'),
        ),
        builder: (context, label) {
          final t = _controller.value.clamp(0.0, 1.0);
          final master = MasterCompleteAchievementTiming.masterOpacity(t);
          final scale = MasterCompleteAchievementTiming.entranceScale(t);
          final scrim = MasterCompleteAchievementTiming.scrimOpacity(t);
          final blur = MasterCompleteAchievementTiming.blurSigma(t);
          final effects = MasterCompleteAchievementTiming.effectsIntensity(t);

          return PopScope(
            canPop: false,
            child: AbsorbPointer(
              child: Material(
              type: MaterialType.transparency,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRect(
                    child: BackdropFilter(
                      key: const Key('master_complete_achievement_backdrop'),
                      filter: _blurFilterFor(blur),
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: scrim),
                      ),
                    ),
                  ),
                  Center(
                    child: Opacity(
                      opacity: master,
                      child: Transform.scale(
                        scale: scale,
                        child: SizedBox(
                          width: 280,
                          height: 240,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              RepaintBoundary(
                                child: CustomPaint(
                                  key: const Key(
                                    'master_complete_achievement_particles',
                                  ),
                                  painter: MasterCompleteAchievementEffectsPainter(
                                    progress: t,
                                    intensity: effects,
                                  ),
                                  size: const Size(280, 240),
                                ),
                              ),
                              label!,
                            ],
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
}

class _AchievementLabel extends StatelessWidget {
  const _AchievementLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '👑',
          style: textTheme.headlineMedium?.copyWith(
            height: 1,
            shadows: [
              Shadow(
                color: MasterCompleteAchievementColors.gold
                    .withValues(alpha: 0.28),
                blurRadius: 14,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          CollectionVocabulary.masterComplete,
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.35,
            color: Color.lerp(
              MasterCompleteAchievementColors.goldDeep,
              scheme.onSurface,
              0.28,
            ),
            shadows: [
              Shadow(
                color: MasterCompleteAchievementColors.gold
                    .withValues(alpha: 0.42),
                blurRadius: 22,
              ),
              Shadow(
                color: MasterCompleteAchievementColors.goldSoft
                    .withValues(alpha: 0.18),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
