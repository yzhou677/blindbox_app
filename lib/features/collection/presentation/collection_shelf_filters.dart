import 'package:flutter/foundation.dart';

/// Progress bucket for Collection advanced filters (single-select).
///
/// Mutually exclusive by design — a series matches at most one option.
enum CollectionShelfProgressFilter {
  /// Owns ≥1 unique figure and is not [SeriesCompletionResolution.isCompleted].
  inProgress,

  /// Regular set complete, but not Master Complete.
  completed,

  /// Satisfies [SeriesCompletionResolution.isMasterComplete].
  masterComplete,
}

/// Unified Collection shelf filter state (Progress / Attributes / Brand / IP).
///
/// ## Combination semantics
///
/// - Progress: single-select (OR within the group by exclusivity)
/// - Brands: OR across selected brand keys; empty = any brand
/// - IPs: OR across selected IP keys; empty = any IP
/// - Collection Attributes: AND across enabled flags
/// - Sections combine with AND
/// - Search (outside this model) remains AND with the applied filters
///
/// Time windows (Recently Added / Recently Released) belong in
/// [CollectionShelfSort], not here.
///
/// Filtering must run through [applyCollectionShelfFilters] — widgets only
/// edit this state.
@immutable
class CollectionShelfFilters {
  const CollectionShelfFilters({
    this.progress,
    this.hasDuplicates = false,
    this.hasWishlistItems = false,
    this.secretOwned = false,
    this.secretMissing = false,
    this.customSeries = false,
    this.brandIds = const {},
    this.ipIds = const {},
  });

  /// Null means any progress state.
  final CollectionShelfProgressFilter? progress;

  final bool hasDuplicates;
  final bool hasWishlistItems;
  final bool secretOwned;
  final bool secretMissing;
  final bool customSeries;

  /// Normalized brand facet keys ([normalizeCollectionFacetFilterKey]).
  final Set<String> brandIds;

  /// Normalized IP facet keys.
  final Set<String> ipIds;

  static const empty = CollectionShelfFilters();

  /// Count of discrete active controls (each brand/IP selection counts as one).
  int get activeCount {
    var n = 0;
    if (progress != null) n++;
    if (hasDuplicates) n++;
    if (hasWishlistItems) n++;
    if (secretOwned) n++;
    if (secretMissing) n++;
    if (customSeries) n++;
    n += brandIds.length;
    n += ipIds.length;
    return n;
  }

  bool get hasActive => activeCount > 0;

  CollectionShelfFilters copyWith({
    CollectionShelfProgressFilter? progress,
    bool clearProgress = false,
    bool? hasDuplicates,
    bool? hasWishlistItems,
    bool? secretOwned,
    bool? secretMissing,
    bool? customSeries,
    Set<String>? brandIds,
    Set<String>? ipIds,
  }) {
    return CollectionShelfFilters(
      progress: clearProgress ? null : (progress ?? this.progress),
      hasDuplicates: hasDuplicates ?? this.hasDuplicates,
      hasWishlistItems: hasWishlistItems ?? this.hasWishlistItems,
      secretOwned: secretOwned ?? this.secretOwned,
      secretMissing: secretMissing ?? this.secretMissing,
      customSeries: customSeries ?? this.customSeries,
      brandIds: brandIds ?? this.brandIds,
      ipIds: ipIds ?? this.ipIds,
    );
  }

  CollectionShelfFilters cleared() => empty;

  CollectionShelfFilters toggleProgress(CollectionShelfProgressFilter value) {
    if (progress == value) return copyWith(clearProgress: true);
    return copyWith(progress: value);
  }

  CollectionShelfFilters toggleBrandId(String id) {
    final next = Set<String>.from(brandIds);
    if (!next.add(id)) next.remove(id);
    return copyWith(brandIds: next);
  }

  CollectionShelfFilters toggleIpId(String id) {
    final next = Set<String>.from(ipIds);
    if (!next.add(id)) next.remove(id);
    return copyWith(ipIds: next);
  }

  @override
  bool operator ==(Object other) {
    return other is CollectionShelfFilters &&
        other.progress == progress &&
        other.hasDuplicates == hasDuplicates &&
        other.hasWishlistItems == hasWishlistItems &&
        other.secretOwned == secretOwned &&
        other.secretMissing == secretMissing &&
        other.customSeries == customSeries &&
        setEquals(other.brandIds, brandIds) &&
        setEquals(other.ipIds, ipIds);
  }

  @override
  int get hashCode => Object.hash(
    progress,
    hasDuplicates,
    hasWishlistItems,
    secretOwned,
    secretMissing,
    customSeries,
    Object.hashAllUnordered(brandIds),
    Object.hashAllUnordered(ipIds),
  );
}
