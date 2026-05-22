import 'package:blindbox_app/core/theme/collectible_shape.dart';
import 'package:flutter/material.dart';

/// Shared corner radii — keep in sync with [CollectibleShape].
abstract final class AppRadii {
  AppRadii._();

  static const double shell = CollectibleShape.shell;
  static const double mat = CollectibleShape.mat;
  static const double inset = CollectibleShape.inset;
  static const double field = CollectibleShape.field;

  /// Browse rows, figure capsules, recommendation tiles.
  static const double card = 22;

  /// Hero covers, sheet tops, release spotlight frames.
  static const double spotlight = 26;

  /// Figure thumbnails / lineup cells — soft collectible frame.
  static const double figureThumb = 20;
  static const double figureLineup = 18;
  static const double figureGallery = 24;

  static BorderRadius get shellRadius => BorderRadius.circular(shell);
  static BorderRadius get matRadius => BorderRadius.circular(mat);
  static BorderRadius get insetRadius => BorderRadius.circular(inset);
  static BorderRadius get cardRadius => BorderRadius.circular(card);
  static BorderRadius get spotlightRadius => BorderRadius.circular(spotlight);
  static BorderRadius get fieldRadius => CollectibleShape.fieldRadius;
  static BorderRadius get figureThumbRadius =>
      BorderRadius.circular(figureThumb);
  static BorderRadius get figureLineupRadius =>
      BorderRadius.circular(figureLineup);
  static BorderRadius get figureGalleryRadius =>
      BorderRadius.circular(figureGallery);

  /// Standard modal bottom sheet (matches [AppTheme.bottomSheetTheme]).
  static ShapeBorder get sheetShape => const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(spotlight)),
  );
}
