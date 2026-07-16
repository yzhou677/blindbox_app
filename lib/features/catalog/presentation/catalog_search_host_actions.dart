import 'package:blindbox_app/features/collection/presentation/collection_series_shelf_cta_presentation.dart';
import 'package:flutter/material.dart';

/// Host-injected row actions — preview and shelf CTA without routing knowledge.
class CatalogSearchHostActions {
  const CatalogSearchHostActions({
    required this.ctaLayout,
    required this.onOpenPreview,
    required this.onShelfCtaPressed,
    this.onWishlistPressed,
  });

  final CollectionSeriesShelfCtaLayout ctaLayout;

  final void Function(
    BuildContext context, {
    required String seriesId,
    String? searchQuery,
  })
  onOpenPreview;

  final void Function(
    BuildContext context, {
    required String seriesId,
    String? searchQuery,
  })
  onShelfCtaPressed;

  final void Function(
    BuildContext context, {
    required String seriesId,
    String? searchQuery,
  })?
  onWishlistPressed;
}

/// What to show below the field when the trimmed query is empty.
enum CatalogSearchIdleBody {
  /// Discover: recent searches (or suggested searches when history is empty).
  recentSearches,

  /// Add Series: host shows Browse instead of history.
  none,
}

/// Layout embedding for [CatalogSearchExperience].
enum CatalogSearchPresentation {
  /// Full Discover screen via [FeedSearchScreen].
  discoverScreen,

  /// Sheet slivers — field plus optional results; host adds Browse when idle.
  embeddedSlivers,
}
