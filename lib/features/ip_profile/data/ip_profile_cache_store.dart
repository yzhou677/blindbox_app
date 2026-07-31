import 'package:blindbox_app/features/ip_profile/domain/ip_introduction_profile.dart';
import 'package:blindbox_app/features/ip_profile/domain/ip_profile_cache_policy.dart';
import 'package:flutter/foundation.dart';

/// Structured per-ipId cache entry (success ≠ missing ≠ failure).
@immutable
class IpProfileCacheEntry {
  const IpProfileCacheEntry({
    this.validProfile,
    this.validFetchedAt,
    this.missingConfirmedAt,
    this.malformedAt,
    this.needsRevalidation = false,
    this.hasRetryableFailure = false,
    this.hasPermanentFailure = false,
  });

  /// Last successfully validated profile (kept across failed refreshes).
  final IpIntroductionProfile? validProfile;
  final DateTime? validFetchedAt;

  /// Server-confirmed document absence.
  final DateTime? missingConfirmedAt;

  /// Document existed but failed validation/mapping.
  final DateTime? malformedAt;

  /// Soft-dirty after PTR / reconnect / TTL — next lookup prefers server.
  final bool needsRevalidation;

  /// Last attempt ended in a transient failure (not a miss).
  final bool hasRetryableFailure;

  /// Last attempt ended in a permanent failure (not a miss).
  final bool hasPermanentFailure;

  bool get hasValidProfile =>
      validProfile != null && validProfile!.isValidForIntroduction;

  IpProfileCacheEntry copyWith({
    IpIntroductionProfile? validProfile,
    DateTime? validFetchedAt,
    DateTime? missingConfirmedAt,
    DateTime? malformedAt,
    bool? needsRevalidation,
    bool? hasRetryableFailure,
    bool? hasPermanentFailure,
    bool clearMissing = false,
    bool clearMalformed = false,
    bool clearValid = false,
  }) {
    return IpProfileCacheEntry(
      validProfile: clearValid ? null : (validProfile ?? this.validProfile),
      validFetchedAt: clearValid
          ? null
          : (validFetchedAt ?? this.validFetchedAt),
      missingConfirmedAt: clearMissing
          ? null
          : (missingConfirmedAt ?? this.missingConfirmedAt),
      malformedAt: clearMalformed ? null : (malformedAt ?? this.malformedAt),
      needsRevalidation: needsRevalidation ?? this.needsRevalidation,
      hasRetryableFailure: hasRetryableFailure ?? this.hasRetryableFailure,
      hasPermanentFailure: hasPermanentFailure ?? this.hasPermanentFailure,
    );
  }
}

/// Process-local structured IP profile cache (not Firestore).
class IpProfileCacheStore {
  IpProfileCacheStore({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, IpProfileCacheEntry> _entries = {};

  @visibleForTesting
  Map<String, IpProfileCacheEntry> get debugEntries =>
      Map.unmodifiable(_entries);

  IpProfileCacheEntry? operator [](String ipId) => _entries[ipId];

  void operator []=(String ipId, IpProfileCacheEntry entry) {
    _entries[ipId] = entry;
  }

  void clear() => _entries.clear();

  DateTime now() => _clock();

  bool isSuccessFresh(IpProfileCacheEntry entry) {
    final at = entry.validFetchedAt;
    if (!entry.hasValidProfile || at == null) return false;
    if (entry.needsRevalidation) return false;
    return now().difference(at) < IpProfileCachePolicy.successTtl;
  }

  bool isMissingFresh(IpProfileCacheEntry entry) {
    final at = entry.missingConfirmedAt;
    if (at == null) return false;
    if (entry.needsRevalidation) return false;
    return now().difference(at) < IpProfileCachePolicy.missingTtl;
  }

  bool isMalformedFresh(IpProfileCacheEntry entry) {
    final at = entry.malformedAt;
    if (at == null) return false;
    if (entry.needsRevalidation) return false;
    return now().difference(at) < IpProfileCachePolicy.malformedTtl;
  }

  /// Pull-to-refresh / reconnect: keep last valid profiles, clear negatives
  /// and failures, mark successes for server revalidation.
  void prepareForRevalidation() {
    if (_entries.isEmpty) return;
    final keys = _entries.keys.toList(growable: false);
    for (final key in keys) {
      final entry = _entries[key]!;
      _entries[key] = entry.copyWith(
        clearMissing: true,
        clearMalformed: true,
        hasRetryableFailure: false,
        hasPermanentFailure: false,
        needsRevalidation: entry.hasValidProfile,
      );
    }
  }

  /// Drop only retryable failure flags / negatives eligibility without
  /// forcing every success through server (used when coalescing recovery).
  void clearRetryableFailuresAndNegatives() {
    prepareForRevalidation();
  }
}
