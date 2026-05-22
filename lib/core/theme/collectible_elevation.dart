import 'package:flutter/material.dart';

/// Soft depth for browse cards and nested mats (not full shelf shells).
abstract final class CollectibleElevation {
  CollectibleElevation._();

  static List<BoxShadow> softCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: scheme.shadow.withValues(alpha: isDark ? 0.2 : 0.07),
        blurRadius: isDark ? 14 : 12,
        offset: const Offset(0, 4),
        spreadRadius: -3,
      ),
    ];
  }
}
