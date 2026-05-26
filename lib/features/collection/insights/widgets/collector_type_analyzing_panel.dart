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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CollectibleMotion.shimmer,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final haloAlpha = 0.06 + t * 0.08;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: CollectibleShape.shellRadius,
            color: scheme.surfaceContainerLow,
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: haloAlpha),
                blurRadius: 28 + t * 12,
                spreadRadius: -4,
              ),
            ],
          ),
          child: child,
        );
      },
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
