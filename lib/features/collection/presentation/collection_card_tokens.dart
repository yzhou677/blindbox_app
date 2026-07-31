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
  /// per-card meta count use this extent.
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

  // —— Wishlist Figure (family-specific; not Series browse height) ——

  /// Figure name budget on Wishlist Figure cards.
  static const int wishlistFigureTitleMaxLines = 2;

  /// Parent series name budget on Wishlist Figure cards.
  static const int wishlistFigureSeriesMaxLines = 2;

  /// Brand / studio footer budget on Wishlist Figure cards.
  static const int wishlistFigureBrandMaxLines = 1;

  /// One title line under AppTheme light [CollectibleTypography.catalogSeriesRowTitle].
  static const double wishlistFigureTitleLineExtent = 22;

  /// One body/meta line under series-IP / brand footer typography (~12–14sp).
  static const double wishlistFigureBodyLineExtent = 18;

  /// Subpixel + font-metric slack so packed footers do not overflow.
  static const double wishlistFigurePackSlack = 4;

  /// Explicit packed height for Wishlist Figure cards:
  /// square cover + 2-line title + 2-line series + 1-line brand + token gaps.
  ///
  /// Independent of [minRailHeight] / [maxPackedMinRailHeight] — do not derive
  /// Figure extent from Series progress-card calibration.
  static double wishlistFigureHeight([
    TextScaler textScaler = TextScaler.noScaling,
  ]) {
    final scale = textScaler.scale(1).clamp(1.0, 3.0);
    final titleBlock =
        wishlistFigureTitleLineExtent * wishlistFigureTitleMaxLines * scale;
    final seriesBlock =
        wishlistFigureBodyLineExtent * wishlistFigureSeriesMaxLines * scale;
    final brandBlock =
        wishlistFigureBodyLineExtent * wishlistFigureBrandMaxLines * scale;
    return padding.vertical +
        coverExtent +
        imageToTitleGap +
        titleBlock +
        titleToMetaGap +
        seriesBlock +
        metaToProgressGap +
        brandBlock +
        wishlistFigurePackSlack;
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
