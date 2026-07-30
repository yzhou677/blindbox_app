import 'dart:async';

import 'package:blindbox_app/features/ip_profile/data/ip_profile_cache_store.dart';
import 'package:blindbox_app/features/ip_profile/data/ip_profile_document_source.dart';
import 'package:blindbox_app/features/ip_profile/data/ip_profile_mapper.dart';
import 'package:blindbox_app/features/ip_profile/domain/ip_introduction_profile.dart';
import 'package:blindbox_app/features/ip_profile/domain/ip_profile_cache_policy.dart';
import 'package:blindbox_app/features/ip_profile/data/ip_profile_fetch_error.dart';
import 'package:flutter/foundation.dart';

/// Read-only access to rich IP introduction docs (`ip_profiles/{ipId}`).
abstract class IpProfileRepository {
  /// Looks up by stable [ipId] only — never by display name or series title.
  ///
  /// Returns the last valid profile when available (including stale fallback
  /// after a failed refresh). Returns `null` when there is nothing displayable.
  Future<IpIntroductionProfile?> fetchByIpId(
    String ipId, {
    IpProfileFetchMode mode = IpProfileFetchMode.cacheFirst,
  });

  /// Discover pull-to-refresh / reconnect: clear negatives & retryable
  /// failures; mark successful entries for on-demand server revalidation.
  void prepareForRevalidation();
}

class FirestoreIpProfileRepository implements IpProfileRepository {
  FirestoreIpProfileRepository({
    IpProfileDocumentSource? source,
    IpProfileCacheStore? cache,
    Future<void> Function(Duration delay)? delay,
    DateTime Function()? clock,
  }) : _source = source ?? FirestoreIpProfileDocumentSource(),
       _cache = cache ?? IpProfileCacheStore(clock: clock),
       _delay = delay ?? Future<void>.delayed;

  final IpProfileDocumentSource _source;
  final IpProfileCacheStore _cache;
  final Future<void> Function(Duration delay) _delay;

  /// In-flight coalescing — separate from completed cache storage.
  final Map<String, Future<IpIntroductionProfile?>> _inflight = {};

  /// Shared process-local cache for the default repository instance.
  static final IpProfileCacheStore sharedCache = IpProfileCacheStore();

  /// Test helper — clears shared cache + allows test repos to reset.
  @visibleForTesting
  static void debugClearCache() {
    sharedCache.clear();
  }

  @visibleForTesting
  IpProfileCacheStore get debugCache => _cache;

  @visibleForTesting
  Map<String, Future<IpIntroductionProfile?>> get debugInflight => _inflight;

  factory FirestoreIpProfileRepository.shared({
    IpProfileDocumentSource? source,
    Future<void> Function(Duration delay)? delay,
  }) {
    return FirestoreIpProfileRepository(
      source: source,
      cache: sharedCache,
      delay: delay,
    );
  }

  @override
  void prepareForRevalidation() => _cache.prepareForRevalidation();

  @override
  Future<IpIntroductionProfile?> fetchByIpId(
    String ipId, {
    IpProfileFetchMode mode = IpProfileFetchMode.cacheFirst,
  }) async {
    final id = ipId.trim();
    if (id.isEmpty) return null;

    final existing = _inflight[id];
    if (existing != null) return existing;

    final future = _lookup(id, mode: mode);
    _inflight[id] = future;
    try {
      return await future;
    } finally {
      if (identical(_inflight[id], future)) {
        _inflight.remove(id);
      }
    }
  }

  Future<IpIntroductionProfile?> _lookup(
    String id, {
    required IpProfileFetchMode mode,
  }) async {
    final preferServer = mode == IpProfileFetchMode.preferServer;
    final cached = _cache[id];

    if (!preferServer && cached != null) {
      if (_cache.isSuccessFresh(cached)) {
        return cached.validProfile;
      }
      if (_cache.isMissingFresh(cached) && !cached.hasValidProfile) {
        return null;
      }
      if (_cache.isMalformedFresh(cached) && !cached.hasValidProfile) {
        return null;
      }
      // Permanent failure with no valid profile: do not hammer this interaction,
      // but prepareForRevalidation / preferServer can still retry later.
      if (cached.hasPermanentFailure &&
          !cached.hasValidProfile &&
          !cached.needsRevalidation) {
        return null;
      }
    }

    final needsServer =
        preferServer ||
        cached == null ||
        cached.needsRevalidation ||
        (cached.hasValidProfile && !_cache.isSuccessFresh(cached)) ||
        cached.hasRetryableFailure ||
        (cached.missingConfirmedAt != null && !_cache.isMissingFresh(cached)) ||
        (cached.malformedAt != null && !_cache.isMalformedFresh(cached));

    if (!needsServer && cached.hasValidProfile) {
      return cached.validProfile;
    }

    return _fetchWithRetry(id, preferServer: true);
  }

  Future<IpIntroductionProfile?> _fetchWithRetry(
    String id, {
    required bool preferServer,
  }) async {
    Object? lastError;
    var lastKind = IpProfileFailureKind.transient;

    for (
      var attempt = 0;
      attempt < IpProfileCachePolicy.maxAttempts;
      attempt++
    ) {
      final backoff = IpProfileCachePolicy.backoffBeforeAttempt(attempt);
      if (backoff != null) {
        await _delay(backoff);
      }

      try {
        final remote = await _source.fetch(id, preferServer: preferServer);
        return _applyRemote(id, remote);
      } catch (error, stack) {
        lastError = error;
        lastKind = classifyIpProfileFailure(error);
        assert(() {
          debugPrint(
            'IpProfileRepository: attempt ${attempt + 1}/'
            '${IpProfileCachePolicy.maxAttempts} failed for '
            'ip_profiles/$id — $error',
          );
          debugPrint('$stack');
          return true;
        }());
        if (lastKind == IpProfileFailureKind.permanent) {
          break;
        }
      }
    }

    final previous = _cache[id];
    if (lastKind == IpProfileFailureKind.permanent) {
      _cache[id] = (previous ?? const IpProfileCacheEntry()).copyWith(
        hasPermanentFailure: true,
        hasRetryableFailure: false,
        needsRevalidation: false,
      );
    } else {
      // Transient: never cache as missing; keep last valid; stay retryable.
      _cache[id] = (previous ?? const IpProfileCacheEntry()).copyWith(
        hasRetryableFailure: true,
        hasPermanentFailure: false,
        // Soft-dirty so reconnect / next preferServer retries.
        needsRevalidation: true,
      );
    }

    assert(() {
      if (lastError != null) {
        debugPrint(
          'IpProfileRepository: giving up for ip_profiles/$id '
          '($lastKind) — $lastError',
        );
      }
      return true;
    }());

    return previous?.validProfile;
  }

  IpIntroductionProfile? _applyRemote(
    String id,
    IpProfileRemoteDocument remote,
  ) {
    final previous = _cache[id];

    if (!remote.exists) {
      // Offline SDK-cache miss must not become a confirmed server absence.
      if (remote.isFromCache) {
        _cache[id] = (previous ?? const IpProfileCacheEntry()).copyWith(
          hasRetryableFailure: true,
          needsRevalidation: true,
        );
        return previous?.validProfile;
      }

      // Confirmed server absence replaces any prior success for this ipId.
      _cache[id] = IpProfileCacheEntry(
        missingConfirmedAt: _cache.now(),
        needsRevalidation: false,
        hasRetryableFailure: false,
        hasPermanentFailure: false,
      );
      return null;
    }

    final profile = mapIpIntroductionProfile(
      documentId: remote.documentId,
      data: remote.data,
    );

    if (profile == null) {
      assert(() {
        debugPrint(
          'IpProfileRepository: malformed ip_profiles/$id '
          '(document exists but failed validation)',
        );
        return true;
      }());
      _cache[id] = IpProfileCacheEntry(
        validProfile: previous?.validProfile,
        validFetchedAt: previous?.validFetchedAt,
        malformedAt: _cache.now(),
        needsRevalidation: false,
        hasRetryableFailure: false,
        hasPermanentFailure: false,
      );
      // Keep last valid visible if a later edit broke the doc temporarily.
      return previous?.validProfile;
    }

    _cache[id] = IpProfileCacheEntry(
      validProfile: profile,
      validFetchedAt: _cache.now(),
      needsRevalidation: false,
      hasRetryableFailure: false,
      hasPermanentFailure: false,
    );
    return profile;
  }
}

/// In-memory repository for tests and provider overrides.
class MemoryIpProfileRepository implements IpProfileRepository {
  MemoryIpProfileRepository([Map<String, IpIntroductionProfile?>? seed])
    : _byId = Map<String, IpIntroductionProfile?>.from(seed ?? const {});

  final Map<String, IpIntroductionProfile?> _byId;
  bool _revalidatePending = false;

  /// Records lookup keys used — tests assert display names are never queried.
  final List<String> requestedIds = [];

  void put(String ipId, IpIntroductionProfile? profile) {
    _byId[ipId.trim()] = profile;
  }

  @override
  void prepareForRevalidation() {
    _revalidatePending = true;
  }

  @visibleForTesting
  bool get debugRevalidatePending => _revalidatePending;

  @override
  Future<IpIntroductionProfile?> fetchByIpId(
    String ipId, {
    IpProfileFetchMode mode = IpProfileFetchMode.cacheFirst,
  }) async {
    final id = ipId.trim();
    requestedIds.add(id);
    if (id.isEmpty) return null;
    if (mode == IpProfileFetchMode.preferServer) {
      _revalidatePending = false;
    }
    return _byId[id];
  }
}
