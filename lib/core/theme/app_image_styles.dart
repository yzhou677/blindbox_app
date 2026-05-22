import 'package:flutter/material.dart';

/// Shared image presentation tokens (fade, mats, shadows, slot sizes).
abstract final class AppImageStyles {
  AppImageStyles._();

  static const double figureThumbExtent = 68;
  static const double figureLineupExtent = 80;

  static const Duration imageFadeIn = Duration(milliseconds: 280);
  static const Duration imageFadeOut = Duration(milliseconds: 140);

  static Color figureMat(ColorScheme scheme) => Color.alphaBlend(
    scheme.surface.withValues(alpha: 0.42),
    scheme.surfaceContainerHighest.withValues(alpha: 0.18),
  );

  static List<BoxShadow> softThumbShadow(ColorScheme scheme) => [
    BoxShadow(
      color: scheme.shadow.withValues(alpha: 0.07),
      blurRadius: 10,
      offset: const Offset(0, 3),
      spreadRadius: -2,
    ),
  ];

  static Border figureThumbBorder(ColorScheme scheme) => Border.all(
    color: scheme.outlineVariant.withValues(alpha: 0.28),
    width: 0.85,
  );
}
