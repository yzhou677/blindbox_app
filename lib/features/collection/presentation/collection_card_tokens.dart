import 'package:blindbox_app/core/theme/app_card_tokens.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Layout tokens for [CollectionSeriesCard] and Collection series rails.
///
/// Extends the shared [AppCardTokens] browse family — Collection adds a compact
/// progress footer, so rail height sits above [AppCardTokens.browseRailHeight]
/// to keep the cover at full [coverExtent] (image-first).
///
/// [compactWidth] / compact packed heights power Insights dashboard rails — same
/// visual family, tighter footprint.
abstract final class CollectionCardTokens {
  CollectionCardTokens._();

  /// Same width as For You / Chasers — not a Collection-only magic number.
  static const double width = AppCardTokens.browseRailWidth;

  /// Bottom inset ≥ 16dp so the owned-count line has breathing room.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(10, 10, 10, 16);

  /// Artwork → title (12–16dp band; [AppSpacing.md]).
  static const double imageToTitleGap = AppSpacing.md;

  /// Title → release-date / Card Content meta — keeps date with the title.
  static const double titleToMetaGap = AppSpacing.lg;

  /// Full square cover — do not shrink below this for text/footer.
  static double get coverExtent => AppCardTokens.browseRailThumbExtent(width);

  /// Meta → progress footer (14–16dp band; [AppSpacing.lg]).
  static const double metaToProgressGap = AppSpacing.lg;

  static const double progressBarHeight = 4;

  /// Progress bar → owned-count / complete label.
  static const double progressToLabelGap = AppSpacing.sm;

  /// Inter-line gap inside [CollectionSeriesCardContentMeta] (non-compact).
  static const double metaInterLineGap = 3;

  /// Packed height with **no** Card Content meta and 16dp below the count.
  ///
  /// Calibrated to AppTheme light + two reserved title lines (equal row height
  /// whether the title wraps). Includes +2dp subpixel slack so Completed
  /// footers with a second meta line (e.g. duplicates) do not overflow by a
  /// fraction of a pixel. Prefer [minRailHeightFor] with a meta count.
  static const double minRailHeight = 266;

  /// Extra height when the first Card Content meta line is present.
  static const double metaFirstLineExtent = 31.5;

  /// Extra height for a second Card Content meta line.
  static const double metaSecondLineExtent = 18.5;

  /// Tallest packed Series height (two meta lines) — grids that cannot pass a
  /// per-card meta count (e.g. wishlist) use this extent.
  static const double maxPackedMinRailHeight =
      minRailHeight + metaFirstLineExtent + metaSecondLineExtent;

  /// Packed rail / card height for the given Card Content meta line count.
  ///
  /// [metaLineCount] is 0–2 (selection slots). Rails and cards that share the
  /// same selection stay equal height; unused slots still reserve space so a
  /// row does not jitter when one series omits an optional line.
  static double minRailHeightFor(
    TextScaler textScaler, {
    int metaLineCount = 0,
  }) {
    final extra = (textScaler.scale(1) - 1).clamp(0.0, 2.0);
    final meta = metaLineCount.clamp(0, 2);
    var h = minRailHeight;
    if (meta >= 1) h += metaFirstLineExtent;
    if (meta >= 2) h += metaSecondLineExtent;
    return h + (extra * 88);
  }

  /// Wishlist Figure cards reserve two lines each for figure and series names,
  /// plus a persistent brand footer. The base adds only the 12dp required by
  /// the fixed two-line title slot; larger text receives one
  /// shared grid-wide allowance so neighboring cards remain aligned.
  ///
  /// Uses the tallest Series packed height (two meta lines) so wishlist tiles
  /// stay aligned with Series cards in mixed contexts.
  static const double wishlistFigureBaseHeight = maxPackedMinRailHeight + 12;

  static double wishlistFigureHeight(TextScaler textScaler) {
    final extraScale = (textScaler.scale(1) - 1).clamp(0.0, double.infinity);
    return wishlistFigureBaseHeight + (extraScale * 96);
  }

  // —— Compact (Insights dashboard / mini shelf rail) ——

  static const double compactWidth = 132;

  static const EdgeInsets compactPadding = EdgeInsets.fromLTRB(10, 10, 10, 16);

  static const double compactImageInset = 20;

  static double get compactCoverExtent => compactWidth - compactImageInset;

  static const double compactImageToTitleGap = AppSpacing.md;

  static const double compactTitleToMetaGap = AppSpacing.md;

  static const double compactMetaToProgressGap = AppSpacing.md;

  /// Packed compact height with no meta and 16dp below the count.
  static const double compactMinRailHeight = 205;

  static const double compactMetaFirstLineExtent = 28;

  static const double compactMetaSecondLineExtent = 16;

  static double compactMinRailHeightFor(
    TextScaler textScaler, {
    int metaLineCount = 0,
  }) {
    final extra = (textScaler.scale(1) - 1).clamp(0.0, 2.0);
    final meta = metaLineCount.clamp(0, 2);
    var h = compactMinRailHeight;
    if (meta >= 1) h += compactMetaFirstLineExtent;
    if (meta >= 2) h += compactMetaSecondLineExtent;
    return h + (extra * 72);
  }
}
