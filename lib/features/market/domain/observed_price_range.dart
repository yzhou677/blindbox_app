import 'package:flutter/foundation.dart';

/// Min/max USD observed across grouped listings.
@immutable
class ObservedPriceRange {
  const ObservedPriceRange({
    required this.minUsd,
    required this.maxUsd,
  });

  final double minUsd;
  final double maxUsd;

  bool get isSinglePrice => (maxUsd - minUsd).abs() < 0.01;

  double get midpoint => (minUsd + maxUsd) / 2;
}
