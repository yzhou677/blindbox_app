/// Shared vertical rhythm for main-tab scroll feeds (Home / Market / Collection).
/// Keeps compact headers aligned while giving the status-bar area a little air.
abstract final class FeedRhythm {
  static const double mainTabAppBarToolbarHeight = 52;

  /// Padding below the compact [SliverAppBar] before first body copy or controls.
  static const double belowMainTabAppBar = 10;

  /// Default gap between major Home feed sections (Latest drops ↔ Trending).
  static const double homeMajorSectionGap = 28;

  /// Space from section title row to subtitle / deck copy.
  static const double sectionTitleToSubtitle = 8;

  /// Space from subtitle to the packaging hairline (when both exist).
  static const double sectionSubtitleToMark = 8;

  /// Space from title row to hairline when there is no subtitle.
  static const double sectionTitleToMark = 10;

  /// Space from section header block (including hairline) to horizontal rails / lists.
  static const double sectionHeaderToRail = 14;
}
