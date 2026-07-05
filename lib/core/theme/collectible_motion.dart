import 'package:flutter/material.dart';

/// Shared animation timing — sheets, gallery, micro-interactions, immersive focus.
abstract final class CollectibleMotion {
  CollectibleMotion._();

  // —— Durations ——

  static const Duration sheet = Duration(milliseconds: 360);
  static const Duration sheetDismiss = Duration(milliseconds: 280);
  static const Duration galleryOpen = Duration(milliseconds: 340);
  static const Duration galleryClose = Duration(milliseconds: 280);
  static const Duration crossfade = Duration(milliseconds: 260);
  static const Duration imageSettle = Duration(milliseconds: 380);
  static const Duration press = Duration(milliseconds: 240);
  static const Duration glow = Duration(milliseconds: 1100);
  static const Duration shimmer = Duration(milliseconds: 1400);
  static const Duration sectionReveal = Duration(milliseconds: 320);

  /// Unified expand/collapse for Collection insights dashboard (morph + size).
  static const Duration insightsDashboardTransition =
      Duration(milliseconds: 240);

  // —— Curves (calm, tactile — no bounce gimmicks) ——

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeIn = Curves.easeInCubic;
  static const Curve standard = Curves.easeOutCubic;
  static const Curve springSoft = Curves.easeOutCubic;

  /// Gallery route enter scale (subtle — collectible stays grounded).
  static const double galleryEnterScale = 0.99;

  /// Capsule / thumb press depth.
  static const double pressScale = 0.97;

  /// Completion glow peak scale on shelf cards.
  static const double shelfCompleteScaleHump = 0.004;

  /// Master Complete badge celebration (~1s, local to shelf card stat line).
  static const Duration masterCompleteCelebration = Duration(milliseconds: 1000);

  /// Master Complete badge peak scale during celebration.
  /// Keep ≤ 1.10 — above ~1.15 reads as bounce, not premium settle.
  static const double masterCompleteBadgeScalePeak = 1.08;

  /// Sustained master rows: one soft 👑·✨ blink every ~20s while on shelf.
  static const Duration masterCompleteAmbientInterval = Duration(seconds: 20);

  /// Single ambient blink — brief, not a looped shimmer.
  static const Duration masterCompleteAmbientBlink = Duration(milliseconds: 520);

  /// Builds a curved animation for route / sheet transitions.
  static Animation<double> curved(Animation<double> parent, {bool reverse = false}) {
    return CurvedAnimation(
      parent: parent,
      curve: reverse ? easeIn : easeOut,
      reverseCurve: reverse ? easeOut : easeIn,
    );
  }

  /// Modal sheet presentation style (Flutter 3.22+).
  static AnimationStyle sheetAnimationStyle() {
    return AnimationStyle(
      duration: sheet,
      reverseDuration: sheetDismiss,
      curve: easeOut,
      reverseCurve: easeIn,
    );
  }
}
