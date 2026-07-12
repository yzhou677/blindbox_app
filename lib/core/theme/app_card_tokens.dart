import 'package:flutter/material.dart';

/// Shared browse-card family tokens (Discover · Market · Collection).
///
/// Surface-specific tokens (e.g. [CollectionCardTokens]) should reference these
/// instead of inventing parallel magic numbers.
abstract final class AppCardTokens {
  AppCardTokens._();

  /// Compact horizontal-rail card width (For You, Chasers, Collection series).
  static const double browseRailWidth = 168;

  /// Discover / Market compact rail height (For You, Chasers).
  static const double browseRailHeight = 196;

  /// Inner padding shared by compact browse-rail cards.
  static const EdgeInsets browseRailPadding = EdgeInsets.fromLTRB(12, 12, 12, 14);

  /// Gap from cover mat to title.
  static const double browseRailImageToTitleGap = 10;

  /// Gap from title to meta / reason line.
  static const double browseRailTitleToMetaGap = 4;

  /// Horizontal inset used to size the square cover (`width - inset`).
  static const double browseRailImageInset = 24;

  static double browseRailThumbExtent([double width = browseRailWidth]) =>
      width - browseRailImageInset;
}
