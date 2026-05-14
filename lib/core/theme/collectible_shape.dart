import 'package:flutter/material.dart';

/// Shared rounded geometry — packaging / shelf mats (keep in sync with [AppTheme] card & chips).
abstract final class CollectibleShape {
  /// Outer product shells (drop cards, listing tiles, shelf rows).
  static const double shell = 28;

  /// Mats, sheets, image wells.
  static const double mat = 18;

  /// Inner figure windows, nested clips.
  static const double inset = 14;

  /// Search fields, tonal blocks.
  static const double field = 20;

  static BorderRadius shellRadius = BorderRadius.circular(shell);
  static BorderRadius matRadius = BorderRadius.circular(mat);
  static BorderRadius insetRadius = BorderRadius.circular(inset);
  static BorderRadius fieldRadius = BorderRadius.circular(field);
}
