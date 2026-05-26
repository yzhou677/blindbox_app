import 'package:flutter/material.dart';

/// Soft accent colors for brand breakdown donut sectors.
abstract final class CollectorTypePalette {
  CollectorTypePalette._();

  static const List<Color> sectorColors = [
    Color(0xFF8A9BC4),
    Color(0xFFB8A8D8),
    Color(0xFF7BA88A),
    Color(0xFFE08A8A),
    Color(0xFFC9A06A),
    Color(0xFF9A8AB8),
    Color(0xFF8A9098),
  ];

  static Color sectorAt(int index) =>
      sectorColors[index % sectorColors.length];
}
