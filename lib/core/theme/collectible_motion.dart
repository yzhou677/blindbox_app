import 'package:flutter/material.dart';

/// Shared animation timing — sheets, gallery, micro-interactions.
abstract final class CollectibleMotion {
  CollectibleMotion._();

  static const Duration sheet = Duration(milliseconds: 320);
  static const Duration galleryOpen = Duration(milliseconds: 280);
  static const Duration galleryClose = Duration(milliseconds: 240);
  static const Duration crossfade = Duration(milliseconds: 220);
  static const Duration press = Duration(milliseconds: 220);
  static const Duration glow = Duration(milliseconds: 920);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeIn = Curves.easeInCubic;
  static const Curve standard = Curves.easeOut;
}
