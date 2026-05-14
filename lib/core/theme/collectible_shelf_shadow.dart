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
    final core = Color.lerp(scheme.shadow, accent, tokens.shellShadowAccentMix)!;
    return [
      BoxShadow(
        color: core.withValues(alpha: alpha),
        blurRadius: tokens.shellShadowBlur,
        offset: Offset(0, tokens.shellShadowDy),
        spreadRadius: tokens.shellShadowSpread,
      ),
      BoxShadow(
        color: Color.lerp(scheme.primary, scheme.surface, isDark ? 0.82 : 0.88)!
            .withValues(alpha: isDark ? 0.055 : 0.032),
        blurRadius: tokens.shellShadowBlur * 1.65,
        offset: Offset(0, tokens.shellShadowDy * 0.45),
        spreadRadius: 0,
      ),
    ];
  }

  /// Extra height a horizontal rail viewport needs below a product shell so
  /// [productShell] is not clipped. Uses the same [CollectibleTokens] fields as the shadow.
  static double horizontalRailShellBottomSlack(CollectibleTokens tokens) {
    final primaryReach = tokens.shellShadowDy + tokens.shellShadowBlur;
    final ambientReach = tokens.shellShadowDy * 0.45 + tokens.shellShadowBlur * 1.65;
    return primaryReach > ambientReach ? primaryReach : ambientReach;
  }
}
