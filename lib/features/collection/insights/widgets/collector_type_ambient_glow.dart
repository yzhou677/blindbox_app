import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:flutter/material.dart';

/// Soft drifting glow behind reveal content — presentation only.
class CollectorTypeAmbientGlow extends StatefulWidget {
  const CollectorTypeAmbientGlow({
    super.key,
    required this.child,
    this.accent,
    this.intensity = 1.0,
  });

  final Widget child;
  final Color? accent;
  final double intensity;

  @override
  State<CollectorTypeAmbientGlow> createState() =>
      _CollectorTypeAmbientGlowState();
}

class _CollectorTypeAmbientGlowState extends State<CollectorTypeAmbientGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CollectibleMotion.shimmer * 6,
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
    final glowColor = widget.accent ?? scheme.primary;
    final i = widget.intensity.clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final t2 = Curves.easeInOut.transform((t + 0.5) % 1.0);
        return DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: (0.04 + t * 0.06) * i),
                blurRadius: 60 + t * 20,
                spreadRadius: -8,
                offset: Offset(-12 + t * 8, -8 + t * 6),
              ),
              BoxShadow(
                color: glowColor.withValues(alpha: (0.03 + t2 * 0.05) * i),
                blurRadius: 70 + t2 * 20,
                spreadRadius: -10,
                offset: Offset(10 - t2 * 6, 12 - t2 * 8),
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
