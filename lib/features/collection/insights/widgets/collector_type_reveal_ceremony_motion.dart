import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';

/// Soft frosted-glass timing for Collector Type reveal ceremony.
///
/// Rhythm (not independent widget flashes):
/// blur → one hero beat (mascot + title + flavor) → pause → Continue → dwell.
abstract final class CollectorTypeRevealCeremonyTiming {
  CollectorTypeRevealCeremonyTiming._();

  static const double blurPeakSigma = 10;
  static const double frostPeak = 0.42;

  static double _safe(double t) => t.clamp(0.0, 1.0);

  static double _span(double t, double start, double end) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return Curves.easeOutCubic.transform(
      ((t - start) / (end - start)).clamp(0.0, 1.0),
    );
  }

  /// Frost / blur — rises early and holds through the reveal (no early fade-out).
  static double backdrop(double t, {required bool first}) {
    t = _safe(t);
    final inEnd = first ? 0.14 : 0.12;
    return _span(t, 0, inEnd);
  }

  static double blurSigma(double t, {required bool first}) =>
      blurPeakSigma * backdrop(t, first: first);

  static double frostOpacity(double t, {required bool first}) =>
      frostPeak * backdrop(t, first: first);

  /// Quiet eyebrow — settles before the hero, stays soft.
  static double intro(double t, {required bool first}) =>
      _span(t, first ? 0.08 : 0.06, first ? 0.18 : 0.15);

  /// Single hero opacity for mascot + title + flavor (one identity beat).
  static double hero(double t, {required bool first}) =>
      _span(t, first ? 0.16 : 0.14, first ? 0.36 : 0.34);

  /// Calm settle inside the same hero window: 0.95 → 1.02 → 1.0
  static double mascotScale(double t, {required bool first}) {
    final local = hero(t, first: first);
    if (local <= 0) return 0.95;
    if (local <= 0.62) {
      return lerpDouble(
        0.95,
        1.02,
        Curves.easeOutCubic.transform(local / 0.62),
      )!;
    }
    return lerpDouble(
      1.02,
      1.0,
      Curves.easeInOutCubic.transform(((local - 0.62) / 0.38).clamp(0.0, 1.0)),
    )!;
  }

  /// Continue appears only after the hero pause (~0.55+).
  static double cta(double t, {required bool first}) =>
      _span(t, first ? 0.55 : 0.54, first ? 0.66 : 0.65);

  /// Soft upward settle for Continue (paired with [cta] opacity).
  static double ctaSlide(double t, {required bool first}) {
    final local = cta(t, first: first);
    return lerpDouble(10, 0, local)!;
  }

  /// Dismiss only once Continue has landed.
  static bool canDismiss(double t, {required bool first}) =>
      cta(t, first: first) >= 0.95;

  /// Hero is fully settled (for tests / pause verification).
  static bool heroSettled(double t, {required bool first}) =>
      hero(t, first: first) >= 0.999;
}

/// Cached blur filters to avoid allocating ImageFilter every frame.
final class CeremonyBlurCache {
  ImageFilter? _filter;
  double _sigma = -1;

  ImageFilter forSigma(double sigma) {
    final quantized = (sigma * 4).round() / 4.0;
    if (_filter != null && _sigma == quantized) return _filter!;
    _sigma = quantized;
    _filter = ImageFilter.blur(sigmaX: quantized, sigmaY: quantized);
    return _filter!;
  }
}
