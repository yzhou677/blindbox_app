import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Soft drifting glow behind reveal content — presentation only.
class CollectorTypeAmbientGlow extends StatefulWidget {
  const CollectorTypeAmbientGlow({
    super.key,
    required this.child,
    this.accent,
    this.intensity = 1.0,
    this.animate = true,
  });

  final Widget child;
  final Color? accent;
  final double intensity;
  final bool animate;

  @override
  State<CollectorTypeAmbientGlow> createState() =>
      _CollectorTypeAmbientGlowState();
}

class _CollectorTypeAmbientGlowState extends State<CollectorTypeAmbientGlow>
    with SingleTickerProviderStateMixin {
  static const double _blurPrimaryBase = 30;
  static const double _blurSecondaryBase = 35;
  static const double _blurDelta = 10;

  late final AnimationController _controller;
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CollectibleMotion.shimmer * 6,
    );
    if (_shouldAnimateGlow) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_shouldAnimateGlow) {
      _routeAnimation?.removeStatusListener(_handleRouteStatus);
      _routeAnimation = null;
      if (_controller.isAnimating) _controller.stop();
      return;
    }
    final nextRouteAnimation = ModalRoute.of(context)?.animation;
    if (_routeAnimation == nextRouteAnimation) return;
    _routeAnimation?.removeStatusListener(_handleRouteStatus);
    _routeAnimation = nextRouteAnimation;
    _routeAnimation?.addStatusListener(_handleRouteStatus);
    final status = _routeAnimation?.status;
    if (status == AnimationStatus.reverse) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant CollectorTypeAmbientGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldAnimateGlow) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteStatus);
    _controller.dispose();
    super.dispose();
  }

  void _handleRouteStatus(AnimationStatus status) {
    if (!_shouldAnimateGlow) return;
    if (status == AnimationStatus.reverse) {
      if (_controller.isAnimating) _controller.stop();
      return;
    }
    if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glowColor = widget.accent ?? scheme.primary;
    final i = widget.intensity.clamp(0.0, 1.0);
    if (!_shouldAnimateGlow) {
      return RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.05 * i),
                blurRadius: 18,
                spreadRadius: -8,
                offset: const Offset(-8, -6),
              ),
              BoxShadow(
                color: glowColor.withValues(alpha: 0.04 * i),
                blurRadius: 22,
                spreadRadius: -10,
                offset: const Offset(8, 10),
              ),
            ],
          ),
          child: widget.child,
        ),
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_controller.value);
          final t2 = Curves.easeInOut.transform((t + 0.5) % 1.0);
          return DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: (0.04 + t * 0.06) * i),
                  blurRadius: _blurPrimaryBase + t * _blurDelta,
                  spreadRadius: -8,
                  offset: Offset(-12 + t * 8, -8 + t * 6),
                ),
                BoxShadow(
                  color: glowColor.withValues(alpha: (0.03 + t2 * 0.05) * i),
                  blurRadius: _blurSecondaryBase + t2 * _blurDelta,
                  spreadRadius: -10,
                  offset: Offset(10 - t2 * 6, 12 - t2 * 8),
                ),
              ],
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }

  bool get _shouldAnimateGlow {
    // Reliability first: animated large-blur shadows are expensive on many
    // Android GPUs and can lead to sustained frame starvation.
    if (defaultTargetPlatform == TargetPlatform.android) return false;
    return widget.animate;
  }
}
