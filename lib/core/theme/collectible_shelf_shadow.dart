import 'package:blindbox_app/core/theme/collectible_tokens.dart';
import 'package:flutter/material.dart';

/// Shelf-style depth for product shells — single source for card/listing shadows.
abstract final class CollectibleShelfShadow {
  static List<BoxShadow> productShell(BuildContext context, {required Color accent}) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final tokens = CollectibleTokens.of(context);
    final isDark = brightness == Brightness.dark;
    final alpha = isDark ? tokens.shellShadowDarkAlpha : tokens.shellShadowLightAlpha;
    return [
      BoxShadow(
        color: Color.lerp(scheme.shadow, accent, tokens.shellShadowAccentMix)!
            .withValues(alpha: alpha),
        blurRadius: tokens.shellShadowBlur,
        offset: Offset(0, tokens.shellShadowDy),
        spreadRadius: tokens.shellShadowSpread,
      ),
    ];
  }
}
