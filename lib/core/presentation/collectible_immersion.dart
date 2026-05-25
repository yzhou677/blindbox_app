import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:flutter/material.dart';

/// Scrim, barrier, and focus framing for immersive collectible viewing.
abstract final class CollectibleImmersion {
  CollectibleImmersion._();

  /// Behind modal bottom sheets — dims feed without harsh blackout.
  static Color sheetBarrier(ColorScheme scheme) =>
      scheme.scrim.withValues(alpha: 0.36);

  /// Fullscreen figure gallery scrim.
  static Color galleryBarrier = Colors.black.withValues(alpha: 0.78);

  /// Slight vignette over gallery stage (figure stays center).
  static Color galleryStageVignette(ColorScheme scheme) =>
      scheme.scrim.withValues(alpha: 0.28);
}

/// Gentle fade-in when a gallery page or focal asset appears.
class CollectiblePresenceFade extends StatefulWidget {
  const CollectiblePresenceFade({
    super.key,
    required this.child,
    this.duration,
  });

  final Widget child;
  final Duration? duration;

  @override
  State<CollectiblePresenceFade> createState() =>
      _CollectiblePresenceFadeState();
}

class _CollectiblePresenceFadeState extends State<CollectiblePresenceFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration ?? CollectibleMotion.imageSettle,
    );
    _opacity = CollectibleMotion.curved(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

/// Opaque sheet body frame — keeps modal chrome detached from the page behind.
///
/// A translucent top gradient caused shelf copy to bleed through the drag handle.
class CollectibleSheetFocusFrame extends StatelessWidget {
  const CollectibleSheetFocusFrame({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: child,
    );
  }
}
