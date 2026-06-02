/// Shared vertical rhythm for main-tab scroll feeds (Home / Market / Collection).
/// Keeps compact headers aligned while giving the status-bar area a little air.
abstract final class FeedRhythm {
  static const double mainTabAppBarToolbarHeight = 52;

  /// Padding below the compact [SliverAppBar] before first body copy or controls.
  static const double belowMainTabAppBar = 10;

  /// Air between tab title ([SliverAppBar]) and [AppSearchField] on Discover / Market.
  static const double headerToSearchField = 14;

  /// Default gap between major Home feed sections (Latest drops ↔ Trending).
  static const double homeMajorSectionGap = 32;

  /// Air between Discover search and the first feed section.
  static const double homeSearchToFirstSection = 16;

  /// Space from section title row to subtitle / deck copy.
  static const double sectionTitleToSubtitle = 8;

  /// Space from subtitle to the packaging hairline (when both exist).
  static const double sectionSubtitleToMark = 8;

  /// Space from title row to hairline when there is no subtitle.
  static const double sectionTitleToMark = 10;

  /// Space from section header block (including hairline) to horizontal rails / lists.
  static const double sectionHeaderToRail = 14;

  /// Space between Market Chasers block and Browse listings header.
  static const double marketChasersToBrowseHeaderGap = 16;

  /// Bottom closure after the Chasers horizontal rail (before [marketChasersToBrowseHeaderGap]).
  static const double marketChasersRailBottomClosure = 22;

  /// @deprecated Use [marketChasersToBrowseHeaderGap].
  static const double marketTrendingToBrowseHeaderGap = marketChasersToBrowseHeaderGap;

  /// @deprecated Use [marketChasersRailBottomClosure].
  static const double marketTrendingRailBottomClosure = marketChasersRailBottomClosure;

  /// Space below the Browse listings section title before the first feed row.
  static const double marketBrowseHeaderToFeedGap = 18;

  /// Vertical gap between Market browse feed rows (gallery pacing, not dense list).
  static const double marketListingFeedCardVerticalGap = 18;

  /// Showcase thumb for Market browse rows.
  static const double marketListingThumbnailExtent = 96;

  /// Chasers rail height (image-first mini cards).
  static const double marketChasersRailHeight = 196;

  /// @deprecated Use [marketChasersRailHeight].
  static const double marketTrendingRailHeight = marketChasersRailHeight;

  /// Home series rails (Latest drops / Trending series).
  static const double homeSeriesRailHeight = 448;

  /// Horizontal showcase card width on Home series rails.
  static const double homeSeriesRailCardWidth = 272;

  /// Compact official updates feed (stacked post tiles).
  static const double homeOfficialFeedThumbnailExtent = 72;
  static const double homeOfficialFeedPostGap = 10;

  /// Square series thumb on shelf cards (browse / recognition).
  static const double collectionShelfThumbnailExtent = 88;

  /// Fixed height for the collection summary metric strip (aligned baselines).
  static const double collectionSummaryMetricStripHeight = 52;

  /// Vertical gap between full-width listing cards (shelf separation).
  static const double listingCardVerticalGap = 22;

  /// Extra air between collection shelf series cards (exhibition pacing).
  static const double collectionShelfCardGap = 26;

  /// Space before the first universe header in the shelf feed.
  static const double collectionUniverseSectionTop = 6;

  /// Calm break between universe groups (header-to-header), not card-to-card gap.
  static const double collectionUniverseSectionGap = 20;

  /// Header deck to first owned series card in a universe group.
  static const double collectionUniverseHeaderToCards = 10;

  /// Air between collection brand filter chips and the first shelf card.
  static const double collectionFilterToFirstCard = 12;

  /// Horizontal gap between cards in home/market rails.
  static const double horizontalRailCardGap = 28;

  /// Vertical gap between stacked blocks inside a tab (e.g. search vs chips).
  static const double blockGapMedium = 18;

  /// Extra air below the last block inside main-tab scroll bodies.
  static const double tabScrollTailPadding = 36;

  // —— Sheets & modals (shared chrome) ——

  /// Target visible height as a fraction of the full screen (not the draggable host).
  static const double sheetOpenScreenFraction = 0.75;
  static const double sheetAddSeriesOpenScreenFraction = 0.80;
  static const double sheetPreviewOpenScreenFraction = 0.75;
  static const double sheetFiguresOpenScreenFraction = 0.80;

  /// Legacy aliases — prefer the `sheet*OpenScreenFraction` names above.
  static const double sheetHeightFraction = sheetOpenScreenFraction;
  static const double sheetAddSeriesHeightFraction =
      sheetAddSeriesOpenScreenFraction;

  /// Lowest visible height before dismiss-on-drag (screen fraction).
  static const double sheetMinScreenFraction = 0.28;

  /// Draggable host + max expand cap (screen fraction).
  static const double sheetMaxChildSize = 0.92;

  /// Legacy alias for [sheetMinScreenFraction] mapped through the host.
  static const double sheetMinChildSize = sheetMinScreenFraction;

  static const double sheetHorizontal = 16;
  static const double sheetChromeTop = 10;
  static const double sheetHeaderAfterHandle = 16;
  static const double sheetBodyBottomInset = 14;
  static const double sheetEditorialBlockGap = 10;
  static const double sheetSectionGap = 18;
  static const double sheetFigureRailGap = 14;

  // —— Detail / hero editorial rhythm (post–Phase 6 density pass) ——

  static const double detailHeroOuterPadding = 10;
  static const double detailHeroInnerPadding = 6;
  static const double detailBodyTopGap = 16;
  static const double detailBodyBottomGap = 28;
  static const double detailHeroToBodyGap = 12;

  /// Max height fraction for figure gallery stage (breathing room above caption).
  static const double galleryStageMaxHeightFactor = 0.88;
}
