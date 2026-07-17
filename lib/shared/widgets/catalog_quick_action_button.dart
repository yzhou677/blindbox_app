import 'package:flutter/material.dart';

/// Universal circular quick action for catalog-like cards.
///
/// Discover uses this for save hearts; Wishlist uses it for remove actions.
class CatalogQuickActionButton extends StatefulWidget {
  const CatalogQuickActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.semanticsLabel,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final String? semanticsLabel;
  final bool active;

  @override
  State<CatalogQuickActionButton> createState() =>
      _CatalogQuickActionButtonState();
}

class _CatalogQuickActionButtonState extends State<CatalogQuickActionButton> {
  static const _pressDuration = Duration(milliseconds: 120);
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
        dimension: 40,
        child: Center(
          child: AnimatedScale(
            scale: _pressed ? 0.94 : 1,
            duration: _pressDuration,
            curve: Curves.easeOutCubic,
            child: Listener(
              onPointerDown: (_) => _setPressed(true),
              onPointerCancel: (_) => _setPressed(false),
              onPointerUp: (_) => _setPressed(false),
              child: IconButton.filledTonal(
                tooltip: widget.tooltip,
                onPressed: widget.onPressed,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: Icon(
                    widget.icon,
                    key: ValueKey<IconData>(widget.icon),
                    size: 18,
                  ),
                ),
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  fixedSize: const Size(32, 32),
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
