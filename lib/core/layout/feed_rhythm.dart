/// Shared vertical rhythm for main-tab scroll feeds (Home / Market / Collection).
/// Keeps compact headers aligned while giving the status-bar area a little air.
abstract final class FeedRhythm {
  static const double mainTabAppBarToolbarHeight = 52;

  /// Padding below the compact [SliverAppBar] before first body copy or controls.
  static const double belowMainTabAppBar = 10;

  /// Air between tab title ([SliverAppBar]) and [AppSearchField] (default).
  static const double headerToSearchField = 14;

  /// Compact title → search for Discover / Market / Collection main tabs.
  static const double compactHeaderToSearchField = 10;

  /// Discover alias for [compactHeaderToSearchField].
  static const double homeHeaderToSearchField = compactHeaderToSearchField;

  /// Default gap between major Home feed sections (Latest drops ↔ Trending).
  static const double homeMajorSectionGap = 24;

  /// Air between Discover search and the first feed section.
  static const double homeSearchToFirstSection = 12;

  /// Compact block gap on Market / Collection (smaller than [blockGapMedium]).
  static const double compactBlockGap = 12;

  /// Space from section title row to subtitle / deck copy.
  static const double sectionTitleToSubtitle = 8;

  /// Space from subtitle to the packaging hairline (when both exist).
  static const double sectionSubtitleToMark = 8;

  /// Space from title row to hairline when there is no subtitle.
  static const double sectionTitleToMark = 10;

  /// Space from section header block (including hairline) to horizontal rails / lists.
  static const double sectionHeaderToRail = 14;

  /// Space between Market Chasers block and Browse listings header.
  static const double marketChasersToBrowseHeaderGap = 12;

  /// Bottom closure after the Chasers horizontal rail (before [marketChasersToBrowseHeaderGap]).
  static const double marketChasersRailBottomClosure = 14;

  /// @deprecated Use [marketChasersToBrowseHeaderGap].
  static const double marketTrendingToBrowseHeaderGap =
      marketChasersToBrowseHeaderGap;

  /// @deprecated Use [marketChasersRailBottomClosure].
  static const double marketTrendingRailBottomClosure =
      marketChasersRailBottomClosure;

  /// Space below the Browse listings section title before the first feed row.
  static const double marketBrowseHeaderToFeedGap = 12;

  /// Vertical gap between Market browse feed rows (gallery pacing, not dense list).
  static const double marketListingFeedCardVerticalGap = 14;

  /// Showcase thumb for Market browse rows.
  static const double marketListingThumbnailExtent = 88;

  /// Chasers rail height — slightly tighter than For You ([AppCardTokens.browseRailHeight]).
  static const double marketChasersRailHeight = 180;

  /// Horizontal gap between Market Chasers cards.
  static const double marketChasersRailCardGap = 16;

  /// @deprecated Use [marketChasersRailHeight].
  static const double marketTrendingRailHeight = marketChasersRailHeight;

  /// Home series rails (Latest drops / Trending series).
  ///
  /// Horizontal list children fill this cross-axis extent. Keep in sync with
  /// [LatestDropCard] fixed height. Prefer `clipBehavior: Clip.none` on the
  /// rail so product-shell shadows are not clipped.
  static const double homeSeriesRailHeight = 368;

  /// Horizontal showcase card width on Home series rails.
  static const double homeSeriesRailCardWidth = 208;

  /// Vertical mat padding around Home series rails (Latest / Trending).
  static const double homeSeriesRailMatVertical = 12;

  /// Horizontal gap between Home series showcase cards (tighter than Market rails).
  static const double homeSeriesRailCardGap = 16;

  /// Compact official updates feed (stacked post tiles).
  static const double homeOfficialFeedThumbnailExtent = 72;
  static const double homeOfficialFeedPostGap = 12;

  /// Card inset — slightly airier than the prior 11/10 stack.
  static const double homeOfficialFeedCardPaddingH = 14;
  static const double homeOfficialFeedCardPaddingV = 14;

  /// Vertical gaps inside an Official feed card (metadata → tags → body → CTA).
  static const double homeOfficialFeedCardSectionGap = 10;
  static const double homeOfficialFeedCardMetaToTagsGap = 8;
  static const double homeOfficialFeedCardTitleToSummaryGap = 5;

  /// Extra air after the last Official feed card before tab scroll tail /
  /// bottom navigation so the final card never feels clipped.
  static const double homeOfficialFeedListBottomPadding = 24;

  /// Square series thumb on shelf cards (browse / recognition).
  static const double collectionShelfThumbnailExtent = 88;

  /// Fixed height for the collection summary metric strip (aligned baselines).
  static const double collectionSummaryMetricStripHeight = 52;

  /// Air between collection search field and summary block.
  static const double collectionSearchToSummaryGap = 12;

  /// Gap between the Summary header row and the summary metrics card.
  static const double collectionSummaryHeaderToCard = 8;

  /// Air between the summary block and the Shelf / Insights segment.
  static const double collectionSummaryToSegmentGap = 12;

  /// Internal Wishlist summary card padding: same total as the default
  /// symmetric 16 + 16 card inset, but weighted lower to visually center two
  /// lightweight metrics.
  static const double collectionWishlistSummaryCardTopPadding = 18;
  static const double collectionWishlistSummaryCardBottomPadding = 14;

  /// Air below the segment before the shelf section header ("My collection").
  static const double collectionSegmentToShelfHeader = 12;

  /// Vertical padding inside the collection summary metric card.
  static const double collectionSummaryCardVerticalPadding = 16;

  /// Gap between the two metric rows in the summary card.
  static const double collectionSummaryMetricRowGap = 12;

  /// Separation between summary metric card and editorial mood line.
  static const double collectionSummaryToEditorial = 18;

  /// Gap between editorial mood and recent-achievement whisper.
  static const double collectionSummaryEditorialGap = 10;

  /// Fixed height for summary count numerals (shared baseline).
  static const double collectionSummaryCountHeight = 24;

  /// Fixed height for summary metric labels (two-line safe).
  static const double collectionSummaryLabelHeight = 32;

  /// Air below summary block before the shelf section header.
  static const double collectionSummaryToShelfHeader = 14;

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

  /// Nested IP group indent under In Progress / Completed bucket headers.
  static const double collectionIpGroupIndent = 10;

  /// Vertical gap between nested IP groups (lighter than bucket spacing).
  static const double collectionIpUniverseSectionGap = 14;

  /// Header-to-cards gap for nested IP groups.
  static const double collectionIpUniverseHeaderToCards = 8;

  /// Section label to chip rail (Brand / IP headings on collection shelf).
  static const double collectionFilterSectionLabelToRail = 6;

  /// Air between brand filter block and IP filter block.
  static const double collectionBrandToIpFilterSectionGap = 10;

  /// Air between collection filter chips and the first shelf card.
  static const double collectionFilterToFirstCard = 10;

  /// Horizontal gap between cards in home/market rails (For You / legacy).
  static const double horizontalRailCardGap = 28;

  /// Horizontal gap between Collection shelf series cards.
  static const double collectionSeriesRailCardGap = 16;

  /// Vertical gap between stacked blocks inside a tab (e.g. search vs chips).
  static const double blockGapMedium = 18;

  /// Insights editorial section gaps — compact but still uneven (not identical cards).
  static const double insightsHeroToStats = 20;
  static const double insightsStatsToProgress = 14;
  static const double insightsProgressToBrand = 16;
  static const double insightsDashboardToJourney = 20;

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

  /// Gap from sheet title block to the first body section.
  static const double sheetTitleToBody = 20;

  /// Bottom inset inside the scroll body (above a sticky footer, if any).
  static const double sheetBodyBottomInset = 24;

  /// Editorial subtitle / meta under a sheet title.
  static const double sheetEditorialBlockGap = 8;

  /// Major section breaks inside sheet bodies (Progress → Attributes → Metadata).
  static const double sheetSectionGap = 24;

  /// Section label → first control / chip row.
  static const double sheetLabelToControl = 12;

  /// Related controls / chip wrap gaps.
  static const double sheetControlGap = 8;

  /// Sticky sheet footer vertical padding (above safe area).
  static const double sheetFooterVertical = 12;

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
