import 'package:flutter/material.dart';

/// Horizontal / vertical rhythm for cards, sheets, and image wells.
///
/// Use [AppSpacing] for component-level insets (card padding, page gutter).
/// Use [FeedRhythm] for compositional layout rhythm (section gaps, rail heights,
/// block gaps, sheet constants).
abstract final class AppSpacing {
  AppSpacing._();

  // ── Primitive scale ──────────────────────────────────────────────────────
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  // ── Page-level gutters ───────────────────────────────────────────────────
  /// Standard horizontal page inset used by feeds, section headers, and cards.
  static const double pageHorizontal = xl; // 20

  /// Compact horizontal inset for rails, official feed columns, and sheet body.
  static const double pageHorizontalCompact = lg; // 16

  /// Horizontal padding for empty-state prompts and centered copy blocks.
  static const double emptyStateHorizontal = 28.0;

  // ── Card interior ────────────────────────────────────────────────────────
  /// Default card body padding (used for collection shelf cards, browse cards).
  static const EdgeInsets cardPadding = EdgeInsets.symmetric(
    horizontal: xl, // 20
    vertical: md, // 12
  );

  /// Compact card body padding (market listing tiles, official feed tiles).
  static const EdgeInsets cardPaddingCompact = EdgeInsets.symmetric(
    horizontal: lg, // 16
    vertical: md, // 12
  );

  // ── Below-AppBar gaps ────────────────────────────────────────────────────
  /// Gap between the main-tab AppBar and the first non-search content.
  /// Matches [FeedRhythm.belowMainTabAppBar].
  static const double belowTabAppBar = 10.0;

  /// Gap between the main-tab AppBar and a search field.
  /// Matches [FeedRhythm.headerToSearchField].
  static const double belowTabAppBarToSearch = 14.0;

  // ── Image wells ──────────────────────────────────────────────────────────
  /// Inset between outer figure frame and art.
  static const EdgeInsets figureThumbInset = EdgeInsets.all(3);

  /// Gallery page side breathing room.
  static const EdgeInsets galleryPage = EdgeInsets.symmetric(horizontal: 14);
}
