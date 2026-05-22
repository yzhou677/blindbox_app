import 'package:flutter/material.dart';

/// Horizontal / vertical rhythm for cards, sheets, and image wells.
abstract final class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  /// Inset between outer figure frame and art.
  static const EdgeInsets figureThumbInset = EdgeInsets.all(3);

  /// Gallery page side breathing room.
  static const EdgeInsets galleryPage = EdgeInsets.symmetric(horizontal: 14);
}
