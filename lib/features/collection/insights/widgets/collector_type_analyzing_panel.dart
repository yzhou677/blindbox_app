import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:flutter/material.dart';

class CollectorTypeAnalyzingPanel extends StatefulWidget {
  const CollectorTypeAnalyzingPanel({super.key});

  @override
  State<CollectorTypeAnalyzingPanel> createState() =>
      _CollectorTypeAnalyzingPanelState();
}

class _CollectorTypeAnalyzingPanelState extends State<CollectorTypeAnalyzingPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CollectibleMotion.shimmer,
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteStatus);
    _controller.dispose();
    super.dispose();
  }

  void _handleRouteStatus(AnimationStatus status) {
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
    final textTheme = Theme.of(context).textTheme;

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: CollectibleShape.shellRadius,
          color: scheme.surfaceContainerLow,
          boxShadow: [
            // Static shadow to avoid continuous large-blur repaints.
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Padding(
        // Compact panel: wider horizontal breathing room than standard cards,
        // generous vertical to let the pulsing dots breathe.
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl, // 24
          vertical: 36,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulsingDots(animation: _controller, scheme: scheme),
            const SizedBox(height: AppSpacing.lg),
            Text(
              CollectorTypeCopy.analyzingLine,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _PulsingDots extends StatelessWidget {
  const _PulsingDots({required this.animation, required this.scheme});

  final Animation<double> animation;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final phase = (animation.value + i * 0.22) % 1.0;
            final scale = 0.7 + 0.3 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withValues(alpha: 0.45),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
