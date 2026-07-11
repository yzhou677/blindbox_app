import 'package:blindbox_app/core/theme/app_card_tokens.dart';
import 'package:flutter/material.dart';

/// Layout tokens for [CollectionSeriesCard] and Collection series rails.
///
/// Extends the shared [AppCardTokens] browse family — Collection adds a compact
/// progress footer, so [minRailHeight] sits above [AppCardTokens.browseRailHeight]
/// to keep the cover at full [coverExtent] (image-first).
abstract final class CollectionCardTokens {
  CollectionCardTokens._();

  /// Same width as For You / Chasers — not a Collection-only magic number.
  static const double width = AppCardTokens.browseRailWidth;

  static const EdgeInsets padding = AppCardTokens.browseRailPadding;

  static const double imageToTitleGap = AppCardTokens.browseRailImageToTitleGap;

  static const double titleToMetaGap = AppCardTokens.browseRailTitleToMetaGap;

  /// Full square cover — do not shrink below this for text/footer.
  static double get coverExtent => AppCardTokens.browseRailThumbExtent(width);

  /// Gap from IP meta to progress footer.
  static const double metaToProgressGap = 8;

  static const double progressBarHeight = 4;

  static const double progressToLabelGap = 4;

  /// Minimum rail / card height — sized so [coverExtent] stays full-bleed.
  ///
  /// The card owns this height; rails use [CollectionSeriesCard.railExtent].
  static const double minRailHeight = 276;
}
