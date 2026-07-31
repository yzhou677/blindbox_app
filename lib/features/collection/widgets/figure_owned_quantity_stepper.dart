import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Compact owned-copy control: `−   N   +`.
///
/// Minimum quantity is `0` (caller clears ownership). Tap targets stay ≥ 40.
class FigureOwnedQuantityStepper extends StatelessWidget {
  const FigureOwnedQuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
  });

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final q = quantity < 0 ? 0 : quantity;

    return Semantics(
      container: true,
      label: 'Owned quantity',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Symbols.remove_rounded,
            semanticLabel: 'Decrease owned quantity',
            enabled: q > 0,
            onPressed: () => onChanged(q - 1),
          ),
          Semantics(
            label: 'Owned quantity $q',
            liveRegion: true,
            child: SizedBox(
              width: 28,
              child: Text(
                '$q',
                textAlign: TextAlign.center,
                style: CollectibleTypography.figureMeta(textTheme, scheme)
                    .copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface.withValues(alpha: 0.88),
                    ),
              ),
            ),
          ),
          _StepButton(
            icon: Symbols.add_rounded,
            semanticLabel: 'Increase owned quantity',
            enabled: true,
            onPressed: () => onChanged(q + 1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.semanticLabel,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 18,
              color: enabled
                  ? scheme.onSurface.withValues(alpha: 0.72)
                  : scheme.onSurface.withValues(alpha: 0.28),
            ),
          ),
        ),
      ),
    );
  }
}
