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

  /// Staggered entrance for recognition candidate cards (start delays).
  static const Duration recognitionCascadeFirst = Duration(milliseconds: 80);
  static const Duration recognitionCascadeSecond = Duration(milliseconds: 120);
  static const Duration recognitionCascadeThird = Duration(milliseconds: 160);

  /// Display-only Finding checklist pacing (~6s staged presentation).
  /// Not tied to backend stages — final Matching step holds until the request
  /// resolves.
  static const Duration recognitionFindingShapeComplete =
      Duration(milliseconds: 900);
  static const Duration recognitionFindingColorsComplete =
      Duration(milliseconds: 1900);
  static const Duration recognitionFindingAccessoriesComplete =
      Duration(milliseconds: 3100);
  static const Duration recognitionFindingFacialComplete =
      Duration(milliseconds: 4400);

  /// Absolute times (from checklist start) when active index advances to the
  /// next step: Colors, Accessories, Facial details, then Matching.
  static const List<Duration> recognitionFindingChecklistAdvanceAt = [
    recognitionFindingShapeComplete,
    recognitionFindingColorsComplete,
    recognitionFindingAccessoriesComplete,
    recognitionFindingFacialComplete,
  ];

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

  /// Global Master Complete achievement overlay (~0.95s, root navigator).
  static const Duration masterCompleteAchievementOverlay =
      Duration(milliseconds: 950);

  /// First-time Collector Type reveal ceremony.
  /// blur → hero → ~750ms pause → Continue → dwell for reaction.
  static const Duration collectorTypeRevealCeremonyFirst =
      Duration(milliseconds: 4200);

  /// Subsequent Collector Type change ceremony (same rhythm, tighter).
  static const Duration collectorTypeRevealCeremonyChange =
      Duration(milliseconds: 3200);

  /// Soft settle for ceremonial mascot entrance (subtle spring, no bounce).
  static const Curve collectorTypeRevealSpring = Cubic(0.22, 1.0, 0.36, 1.0);

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
