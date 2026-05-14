/// Shared vertical rhythm for main-tab scroll feeds (Home / Market / Collection).
/// Keeps compact headers aligned while giving the status-bar area a little air.
abstract final class FeedRhythm {
  static const double mainTabAppBarToolbarHeight = 52;

  /// Padding below the compact [SliverAppBar] before first body copy or controls.
  static const double belowMainTabAppBar = 10;

  /// Default gap between major Home feed sections (Latest drops ↔ Trending).
  static const double homeMajorSectionGap = 32;

  /// Space from section title row to subtitle / deck copy.
  static const double sectionTitleToSubtitle = 8;

  /// Space from subtitle to the packaging hairline (when both exist).
  static const double sectionSubtitleToMark = 8;

  /// Space from title row to hairline when there is no subtitle.
  static const double sectionTitleToMark = 10;

  /// Space from section header block (including hairline) to horizontal rails / lists.
  static const double sectionHeaderToRail = 14;

  /// Space between Market Trending block and Browse listings header.
  static const double marketTrendingToBrowseHeaderGap = 16;

  /// Bottom closure after the Trending horizontal rail (before [marketTrendingToBrowseHeaderGap]).
  static const double marketTrendingRailBottomClosure = 22;

  /// Space below the Browse listings section title before the first feed row.
  static const double marketBrowseHeaderToFeedGap = 18;

  /// Vertical gap between Market browse feed rows (lighter than shelf cards).
  static const double marketListingFeedCardVerticalGap = 14;

  /// Fixed square thumbnail for Market browse feed rows.
  static const double marketListingThumbnailExtent = 92;

  /// Trending rail height (preview cards); lower than browse for hierarchy.
  static const double marketTrendingRailHeight = 180;

  /// Square series thumb on shelf cards (browse / recognition).
  static const double collectionShelfThumbnailExtent = 76;

  /// Fixed height for the collection summary metric strip (aligned baselines).
  static const double collectionSummaryMetricStripHeight = 92;

  /// Vertical gap between full-width listing cards (shelf separation).
  static const double listingCardVerticalGap = 22;

  /// Horizontal gap between cards in home/market rails.
  static const double horizontalRailCardGap = 24;

  /// Vertical gap between stacked blocks inside a tab (e.g. search vs chips).
  static const double blockGapMedium = 18;

  /// Extra air below the last block inside main-tab scroll bodies.
  static const double tabScrollTailPadding = 36;
}
