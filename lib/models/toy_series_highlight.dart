import 'package:flutter/material.dart';

/// Designer IP / series row for universe-style browsing (not a single SKU).
class ToySeriesHighlight {
  const ToySeriesHighlight({
    required this.id,
    required this.name,
    required this.figureCount,
    required this.accent,
    this.brand,
    this.tagline,
  });

  final String id;
  final String name;
  final int figureCount;
  final Color accent;

  /// e.g. POP MART, TNTSPACE
  final String? brand;

  /// Optional cozy subtitle ("quiet stories", "soft chaos", …)
  final String? tagline;
}
