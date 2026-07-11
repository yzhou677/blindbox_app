import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_avatar.dart';
import 'package:flutter/material.dart';

/// Soft halo + [CollectorTypeAvatar] (or icon fallback) for Collector Type.
class CollectorTypeGlyph extends StatefulWidget {
  const CollectorTypeGlyph({
    super.key,
    required this.archetype,
    this.size = 56,
  });

  final CollectorTypeArchetype archetype;
  final double size;

  @override
  State<CollectorTypeGlyph> createState() => _CollectorTypeGlyphState();
}

class _CollectorTypeGlyphState extends State<CollectorTypeGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: CollectibleMotion.glow,
    )..forward();
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.archetype.accentFor(Theme.of(context).brightness);
    final avatar = CollectorTypeAvatar.tryBuild(
      id: widget.archetype.id,
      size: widget.size,
      semanticLabel: widget.archetype.displayName,
    );
    final icon = widget.archetype.icon ?? Icons.auto_awesome_outlined;

    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_glow.value);
        final halo = 0.12 * (1 - t) + 0.04;
        return SizedBox(
          width: widget.size + 24,
          height: widget.size + 24,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: halo),
                  blurRadius: 20 + t * 8,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: avatar ??
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.18),
                ),
                child: Icon(
                  icon,
                  size: widget.size * 0.46,
                  color: accent.withValues(alpha: 0.88),
                ),
              ),
            ),
      ),
    );
  }
}
