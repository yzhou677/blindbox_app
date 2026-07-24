import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/core/theme/shelfy_symbols.dart';
import 'package:flutter/material.dart';

/// Universal circular quick action for catalog-like cards.
///
/// Discover uses this for save hearts; Wishlist uses it for remove actions.
/// Favorite state: same glyph + [filled] / [active] color — not a border glyph.
class CatalogQuickActionButton extends StatefulWidget {
  const CatalogQuickActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.semanticsLabel,
    this.active = false,
    this.filled = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final String? semanticsLabel;
  final bool active;

  /// Solid Material Symbols fill when true (e.g. wishlisted heart).
  final bool filled;

  @override
  State<CatalogQuickActionButton> createState() =>
      _CatalogQuickActionButtonState();
}

class _CatalogQuickActionButtonState extends State<CatalogQuickActionButton> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: widget.semanticsLabel ?? widget.tooltip,
      child: SizedBox.square(
        dimension: AppIconPadding.quickActionHit,
        child: Center(
          child: AnimatedScale(
            scale: _pressed ? CollectibleMotion.pressScale : 1,
            duration: CollectibleMotion.fast,
            curve: CollectibleMotion.easeOut,
            child: Listener(
              onPointerDown: (_) => _setPressed(true),
              onPointerCancel: (_) => _setPressed(false),
              onPointerUp: (_) => _setPressed(false),
              child: IconButton.filledTonal(
                tooltip: widget.tooltip,
                onPressed: widget.onPressed,
                icon: Icon(
                  widget.icon,
                  size: AppIconSizes.quickAction,
                  fill: widget.filled
                      ? ShelfySymbols.fillSolid
                      : ShelfySymbols.fillOutline,
                ),
                style: IconButton.styleFrom(
                  minimumSize: AppIconPadding.quickActionWell,
                  fixedSize: AppIconPadding.quickActionWell,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: scheme.surface.withValues(alpha: 0.86),
                  foregroundColor: widget.active
                      ? scheme.primary
                      : scheme.onSurfaceVariant.withValues(alpha: 0.82),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
