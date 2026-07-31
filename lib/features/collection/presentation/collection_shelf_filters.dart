import 'package:flutter/foundation.dart';

/// Progress bucket for Collection advanced filters (single-select UI).
///
/// Only one Progress option may be selected at a time. Matching sets nest:
/// [completed] ⊆ all finished series (including Master);
/// [masterComplete] is Master-only and does not broaden to regular Completed.
enum CollectionShelfProgressFilter {
  /// Owns ≥1 unique figure and is not [SeriesCompletionResolution.isCompleted].
  inProgress,

  /// Any completed series — includes Master Complete.
  completed,

  /// Satisfies [SeriesCompletionResolution.isMasterComplete] only.
  masterComplete,
}

/// Unified Collection shelf filter state.
///
/// ## Combination semantics
///
/// - **Progress**: single-select; tap selected again to clear
/// - **Secret Status**: single-select (`secretOwned` XOR `secretMissing`)
/// - **Collection Attributes**: independent flags AND together
/// - **Brand** / **IP**: single-select each; empty = all; AND across groups
/// - Sections combine with AND
/// - Search (outside this model) remains AND with the applied filters
///
/// Time windows (Recently Added / Recently Released) belong in
/// [CollectionShelfSort], not here.
///
/// Filtering must run through [applyCollectionShelfFilters] — widgets only
/// edit this state. Prefer [normalizeCollectionShelfFilters] when restoring
/// draft / committed state so legacy multi-select payloads collapse safely.
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

  /// Secret Status — mutually exclusive with [secretMissing].
  final bool secretOwned;

  /// Secret Status — mutually exclusive with [secretOwned].
  final bool secretMissing;

  final bool customSeries;

  /// At most one normalized brand facet key (empty = all brands).
  final Set<String> brandIds;

  /// At most one normalized IP facet key (empty = all IPs).
  final Set<String> ipIds;

  static const empty = CollectionShelfFilters();

  /// Selected brand id when exactly one is set.
  String? get selectedBrandId =>
      brandIds.isEmpty ? null : brandIds.first;

  /// Selected IP id when exactly one is set.
  String? get selectedIpId => ipIds.isEmpty ? null : ipIds.first;

  /// Count of discrete active controls. Empty Brand/IP ("All") do not count.
  int get activeCount {
    var n = 0;
    if (progress != null) n++;
    if (hasDuplicates) n++;
    if (hasWishlistItems) n++;
    if (secretOwned) n++;
    if (secretMissing) n++;
    if (customSeries) n++;
    if (brandIds.isNotEmpty) n++;
    if (ipIds.isNotEmpty) n++;
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

  /// Secret Owned — clears Secret Missing when selecting.
  CollectionShelfFilters toggleSecretOwned() {
    if (secretOwned) return copyWith(secretOwned: false);
    return copyWith(secretOwned: true, secretMissing: false);
  }

  /// Secret Missing — clears Secret Owned when selecting.
  CollectionShelfFilters toggleSecretMissing() {
    if (secretMissing) return copyWith(secretMissing: false);
    return copyWith(secretMissing: true, secretOwned: false);
  }

  /// Brand single-select: tap selected again clears (All).
  CollectionShelfFilters toggleBrandId(String id) {
    if (brandIds.length == 1 && brandIds.contains(id)) {
      return copyWith(brandIds: const {});
    }
    return copyWith(brandIds: {id});
  }

  /// IP single-select: tap selected again clears (All).
  CollectionShelfFilters toggleIpId(String id) {
    if (ipIds.length == 1 && ipIds.contains(id)) {
      return copyWith(ipIds: const {});
    }
    return copyWith(ipIds: {id});
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

/// Collapses legacy / invalid payloads to current single-choice group rules.
///
/// - Secret Owned + Secret Missing → keep Owned, clear Missing
/// - Multiple brand/IP ids → keep the first insertion-order id only
CollectionShelfFilters normalizeCollectionShelfFilters(
  CollectionShelfFilters filters,
) {
  var secretOwned = filters.secretOwned;
  var secretMissing = filters.secretMissing;
  if (secretOwned && secretMissing) {
    secretMissing = false;
  }

  final brands = filters.brandIds;
  final ips = filters.ipIds;
  final nextBrands = brands.length <= 1
      ? brands
      : <String>{brands.first};
  final nextIps = ips.length <= 1 ? ips : <String>{ips.first};

  if (secretOwned == filters.secretOwned &&
      secretMissing == filters.secretMissing &&
      setEquals(nextBrands, brands) &&
      setEquals(nextIps, ips)) {
    return filters;
  }

  return filters.copyWith(
    secretOwned: secretOwned,
    secretMissing: secretMissing,
    brandIds: nextBrands,
    ipIds: nextIps,
  );
}
