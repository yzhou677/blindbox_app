import 'dart:async';

import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_disk_cache.dart';
import 'package:blindbox_app/features/catalog/data/catalog_image_version.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Resolves catalog art from [imageKey] only — never from Firestore paths or URLs.
///
/// **SSOT:** Firestore metadata + Firebase Storage binaries. No APK-bundled catalog art.
///
/// **Firebase Storage** paths (deterministic):
/// - `catalog/series/<imageKey>.<ext>`
/// - `catalog/figures/<imageKey>.<ext>`
///
/// **Runtime resolution order:**
/// 1. Bounded disk cache (resilience — LRU + TTL staleness)
/// 2. Firebase Storage (freshness / enrichment; stale disk renders immediately)
/// 3. Placeholder (null ref)
///
/// Disk cache is **not** canonical storage. Stale entries still paint offline while
/// a deduped background refresh runs when network + Storage are available.
///
/// Offline skips Storage immediately. A probe [TimeoutException] while still
/// online continues to the next extension (missing `.avif` must not block
/// `.webp`), then retries the whole probe up to [maxStorageFetchRetries] times
/// with short backoff. A single-key timeout does **not** gate other keys.
/// The session transport gate trips only when offline, or after
/// [consecutiveTransportFailuresToTripGate] distinct keys exhaust retries;
/// it auto-clears after [transportGateTtl] or when connectivity returns.
/// Transient transport misses are **not** written to the session missing-key cache.
///
/// Download URLs are not written back to Firestore or shelf [imageKey].
abstract final class CatalogImageResolver {
  /// When true (default), resolve from Firebase Storage after a disk miss.
  ///
  /// Set `CATALOG_STORAGE_FALLBACK=false` only to suppress Storage probes (e.g.
  /// catalog-only dev with placeholders). Missing keys are negative-cached so
  /// repeat 404 log spam is avoided without disabling Storage for valid keys.
  static bool get storageFallbackEnabled {
    if (storageFallbackOverride != null) return storageFallbackOverride!;
    return const bool.fromEnvironment(
      'CATALOG_STORAGE_FALLBACK',
      defaultValue: true,
    );
  }

  @visibleForTesting
  static bool? storageFallbackOverride;

  @visibleForTesting
  static bool? firebaseStorageReadyOverride;

  /// When set, replaces Firebase [Reference.getDownloadURL] in tests.
  @visibleForTesting
  static Future<String?> Function(String storageObjectPath)?
  getDownloadUrlOverride;

  /// When set, replaces [Connectivity.checkConnectivity] for online gating.
  @visibleForTesting
  static Future<bool> Function()? isOnlineOverride;

  /// Counts Storage extension probes in the current test session.
  @visibleForTesting
  static int storageExtensionProbeCount = 0;

  @visibleForTesting
  static int backgroundRefreshCount = 0;

  /// Cap for simultaneous stale-while-revalidate background refreshes.
  static const int maxConcurrentStaleRefreshes = 4;

  @visibleForTesting
  static int? maxConcurrentStaleRefreshesOverride;

  @visibleForTesting
  static int get activeStaleRefreshCount => _activeStaleRefreshCount;

  @visibleForTesting
  static int get queuedStaleRefreshCount => _staleRefreshQueue.length;

  /// True after offline / multi-key transport failures until TTL or online again.
  @visibleForTesting
  static bool get storageTransportUnavailable => _storageTransportUnavailable;

  @visibleForTesting
  static int get consecutiveTransportFailureCount =>
      _consecutiveTransportFailures;

  @visibleForTesting
  static int get activeStorageFetchCount => _activeStorageFetches;

  @visibleForTesting
  static void resetSessionCachesForTest() {
    _storageDisplayRefCache.clear();
    _storageMissingCache.clear();
    _storageResolveInFlight.clear();
    _storageRefreshInFlight.clear();
    _staleRefreshQueue.clear();
    _staleRefreshQueuedKeys.clear();
    _activeStaleRefreshCount = 0;
    _activeStorageFetches = 0;
    _storageFetchWaiters.clear();
    _debugLoggedMissingKeys.clear();
    _clearTransportGate();
    storageExtensionProbeCount = 0;
    backgroundRefreshCount = 0;
    maxConcurrentStaleRefreshesOverride = null;
    maxConcurrentStorageFetchesOverride = null;
    maxStorageFetchRetriesOverride = null;
    storageRetryDelaysOverride = null;
    delayOverride = null;
    nowOverride = null;
    firebaseStorageReadyOverride = null;
    getDownloadUrlOverride = null;
    isOnlineOverride = null;
  }

  static const Duration storageUrlTimeout = Duration(seconds: 8);

  /// Retries after a full extension-probe timeout / transport failure (not 404).
  static const int maxStorageFetchRetries = 2;

  @visibleForTesting
  static int? maxStorageFetchRetriesOverride;

  static int get _storageFetchRetryLimit =>
      maxStorageFetchRetriesOverride ?? maxStorageFetchRetries;

  /// Backoff before retry attempts 1 and 2 (plus small jitter).
  static const List<Duration> storageRetryDelays = [
    Duration(milliseconds: 300),
    Duration(milliseconds: 800),
  ];

  @visibleForTesting
  static List<Duration>? storageRetryDelaysOverride;

  /// Cap simultaneous Storage fetch+retry pipelines (retries hold the slot).
  static const int maxConcurrentStorageFetches = 6;

  @visibleForTesting
  static int? maxConcurrentStorageFetchesOverride;

  static int get _storageFetchConcurrencyCap =>
      maxConcurrentStorageFetchesOverride ?? maxConcurrentStorageFetches;

  /// Distinct keys that must exhaust retries before the session gate trips.
  static const int consecutiveTransportFailuresToTripGate = 3;

  /// How long a consecutive-failure gate stays closed while still "online".
  static const Duration transportGateTtl = Duration(seconds: 5);

  /// Test seam for retry backoff sleeps.
  @visibleForTesting
  static Future<void> Function(Duration duration)? delayOverride;

  /// Test seam for gate TTL.
  @visibleForTesting
  static DateTime Function()? nowOverride;

  /// Probe order for Storage (`catalog/series|figures/<imageKey><ext>`).
  ///
  /// Bucket mix is mostly webp / png / jpg with some avif — prefer common
  /// formats first so a slow miss on rare `.avif` does not delay hits.
  /// Each [imageKey] tries every extension here until one object exists (or all miss → placeholder).
  static const List<String> assetExtensions = [
    '.webp',
    '.png',
    '.jpg',
    '.jpeg',
    '.avif',
  ];

  /// Session memory for disk paths or network URLs resolved from Storage tier.
  static final Map<String, String> _storageDisplayRefCache = {};
  static final Set<String> _storageMissingCache = <String>{};
  static final Map<String, Future<String?>> _storageResolveInFlight = {};
  static final Map<String, Future<void>> _storageRefreshInFlight = {};
  static final List<_StaleRefreshJob> _staleRefreshQueue = [];
  static final Set<String> _staleRefreshQueuedKeys = <String>{};
  static int _activeStaleRefreshCount = 0;
  static int _activeStorageFetches = 0;
  static final List<Completer<void>> _storageFetchWaiters = <Completer<void>>[];
  static final Set<String> _debugLoggedMissingKeys = <String>{};

  /// Session gate: offline, or several distinct keys exhausted transport retries.
  static bool _storageTransportUnavailable = false;
  static _TransportGateReason _transportGateReason = _TransportGateReason.none;
  static DateTime? _transportGateUntil;
  static int _consecutiveTransportFailures = 0;

  static int get _staleRefreshConcurrencyCap =>
      maxConcurrentStaleRefreshesOverride ?? maxConcurrentStaleRefreshes;

  static const String storageFiguresPrefix = 'catalog/figures';
  static const String storageSeriesPrefix = 'catalog/series';

  /// Which Storage subtree to use under `catalog/`.
  static String storagePrefixFor(CatalogImageKind kind) => switch (kind) {
    CatalogImageKind.figure => storageFiguresPrefix,
    CatalogImageKind.series => storageSeriesPrefix,
  };

  /// Deterministic Storage object path: `catalog/{series|figures}/<imageKey><ext>`.
  static String storageObjectPath({
    required CatalogImageKind kind,
    required String imageKey,
    required String extension,
  }) {
    final k = imageKey.trim();
    final ext = extension.startsWith('.') ? extension : '.$extension';
    return '${storagePrefixFor(kind)}/$k$ext';
  }

  /// No-op retained for call-site compatibility (formerly warmed AssetManifest).
  static Future<void> ensureReady() async {}

  /// Disk cache or Firebase Storage.
  static Future<String?> resolveFigureStorageRef(
    String imageKey, {
    String? imageVersion,
  }) async {
    final k = imageKey.trim();
    if (k.isEmpty) return null;
    return _resolveStorageDisplayRef(
      CatalogImageKind.figure,
      k,
      imageVersion: imageVersion,
    );
  }

  /// Disk cache or Firebase Storage.
  static Future<String?> resolveSeriesStorageRef(
    String imageKey, {
    String? imageVersion,
  }) async {
    final k = imageKey.trim();
    if (k.isEmpty) return null;
    return _resolveStorageDisplayRef(
      CatalogImageKind.series,
      k,
      imageVersion: imageVersion,
    );
  }

  /// Disk cache, else Storage when [storageFallbackEnabled].
  static Future<String?> resolveFigureDisplayRef(
    String imageKey, {
    String? imageVersion,
  }) async {
    final k = imageKey.trim();
    if (k.isEmpty) return null;
    final storage = await _resolveStorageDisplayRef(
      CatalogImageKind.figure,
      k,
      imageVersion: imageVersion,
    );
    _traceResolution(
      imageKey: k,
      kind: CatalogImageKind.figure,
      phase: 'display_ref',
      outcome: storage != null ? 'storage_url' : 'null',
    );
    return storage;
  }

  /// Disk cache, else Storage when [storageFallbackEnabled].
  static Future<String?> resolveSeriesDisplayRef(
    String imageKey, {
    String? imageVersion,
  }) async {
    final k = imageKey.trim();
    if (k.isEmpty) return null;
    final storage = await _resolveStorageDisplayRef(
      CatalogImageKind.series,
      k,
      imageVersion: imageVersion,
    );
    _traceResolution(
      imageKey: k,
      kind: CatalogImageKind.series,
      phase: 'display_ref',
      outcome: storage != null ? 'storage_url' : 'null',
    );
    return storage;
  }

  /// Looks up `imageVersion` for [imageKey] from the in-memory catalog bundle.
  ///
  /// Checks series covers, figure primaries, and `alternativeImages` entries.
  static String? lookupImageVersion({
    required CatalogImageKind kind,
    required String imageKey,
  }) {
    final bundle = CatalogBundleCache.current;
    if (bundle == null) return null;
    final k = imageKey.trim();
    if (k.isEmpty) return null;
    if (kind == CatalogImageKind.series) {
      for (final s in bundle.series) {
        if (s.imageKey.trim() == k) {
          return CatalogImageVersion.normalize(s.imageVersion);
        }
      }
      return null;
    }
    for (final f in bundle.figures) {
      if (f.imageKey.trim() == k) {
        return CatalogImageVersion.normalize(f.imageVersion);
      }
      for (final alt in f.alternativeImages) {
        if (alt.imageKey.trim() == k) {
          return CatalogImageVersion.normalize(alt.imageVersion);
        }
      }
    }
    return null;
  }

  /// First existing Storage object for [kind] + [imageKey]; returns a download URL for UI only.
  static Future<String?> _resolveStorageDisplayRef(
    CatalogImageKind kind,
    String imageKey, {
    String? imageVersion,
  }) async {
    final k = imageKey.trim();
    if (k.isEmpty) return null;
    final version = CatalogImageVersion.normalize(imageVersion);

    final primaryCacheKey = CatalogImageVersion.diskEntryKey(
      kind: kind,
      imageKey: k,
      imageVersion: version,
    );

    final sessionCached = _storageDisplayRefCache[primaryCacheKey];
    if (sessionCached != null) return sessionCached;

    final diskHit = await CatalogImageDiskCache.lookup(
      kind: kind,
      imageKey: k,
      imageVersion: version,
    );
    if (diskHit != null) {
      _storageDisplayRefCache[primaryCacheKey] = diskHit.localPath;
      _traceResolution(
        imageKey: k,
        kind: kind,
        phase: 'disk_cache',
        hit: true,
        outcome: diskHit.isStale ? 'disk_cache_stale' : 'disk_cache_hit',
      );
      if (diskHit.isStale) {
        _scheduleStaleRefresh(
          kind: kind,
          imageKey: k,
          imageVersion: version,
          primaryCacheKey: primaryCacheKey,
        );
      }
      return diskHit.localPath;
    }

    if (_storageMissingCache.contains(primaryCacheKey)) return null;
    final inFlight = _storageResolveInFlight[primaryCacheKey];
    if (inFlight != null) return inFlight;

    if (!storageFallbackEnabled) {
      _traceResolution(
        imageKey: k,
        kind: kind,
        phase: 'storage',
        storageSkipped: true,
        outcome: 'skipped_disabled',
      );
      return null;
    }
    if (!_firebaseStorageReady) {
      _traceResolution(
        imageKey: k,
        kind: kind,
        phase: 'storage',
        storageSkipped: true,
        outcome: 'skipped_firebase_unready',
      );
      return null;
    }
    if (!await _allowStorageTransport(kind: kind, imageKey: k)) {
      return null;
    }

    final future = _fetchAndPersistFromStorage(
      kind: kind,
      imageKey: k,
      imageVersion: version,
      primaryCacheKey: primaryCacheKey,
      recordMissingOnFailure: true,
    );
    _storageResolveInFlight[primaryCacheKey] = future;
    try {
      return await future;
    } finally {
      _storageResolveInFlight.remove(primaryCacheKey);
    }
  }

  static void _scheduleStaleRefresh({
    required CatalogImageKind kind,
    required String imageKey,
    required String primaryCacheKey,
    String? imageVersion,
  }) {
    if (!storageFallbackEnabled || !_firebaseStorageReady) return;
    if (_storageTransportUnavailable) return;
    if (_storageRefreshInFlight.containsKey(primaryCacheKey)) return;
    if (_staleRefreshQueuedKeys.contains(primaryCacheKey)) return;

    _staleRefreshQueue.add(
      _StaleRefreshJob(
        kind: kind,
        imageKey: imageKey,
        imageVersion: imageVersion,
        primaryCacheKey: primaryCacheKey,
      ),
    );
    _staleRefreshQueuedKeys.add(primaryCacheKey);
    _pumpStaleRefreshQueue();
  }

  static void _pumpStaleRefreshQueue() {
    while (_activeStaleRefreshCount < _staleRefreshConcurrencyCap &&
        _staleRefreshQueue.isNotEmpty) {
      final job = _staleRefreshQueue.removeAt(0);
      _staleRefreshQueuedKeys.remove(job.primaryCacheKey);
      _activeStaleRefreshCount++;
      unawaited(_runQueuedStaleRefresh(job));
    }
  }

  static Future<void> _runQueuedStaleRefresh(_StaleRefreshJob job) async {
    try {
      if (_storageRefreshInFlight.containsKey(job.primaryCacheKey)) return;

      final mayRefresh =
          await CatalogImageDiskCache.shouldAttemptBackgroundRefresh(
            kind: job.kind,
            imageKey: job.imageKey,
            imageVersion: job.imageVersion,
          );
      if (!mayRefresh) return;
      if (_storageRefreshInFlight.containsKey(job.primaryCacheKey)) return;

      await CatalogImageDiskCache.markRefreshAttempted(
        kind: job.kind,
        imageKey: job.imageKey,
        imageVersion: job.imageVersion,
      );

      final refresh = _refreshFromStorage(
        kind: job.kind,
        imageKey: job.imageKey,
        imageVersion: job.imageVersion,
        primaryCacheKey: job.primaryCacheKey,
      );
      _storageRefreshInFlight[job.primaryCacheKey] = refresh;
      await refresh;
    } finally {
      _storageRefreshInFlight.remove(job.primaryCacheKey);
      _activeStaleRefreshCount--;
      _pumpStaleRefreshQueue();
    }
  }

  static Future<void> _refreshFromStorage({
    required CatalogImageKind kind,
    required String imageKey,
    required String primaryCacheKey,
    String? imageVersion,
  }) async {
    backgroundRefreshCount++;
    final updated = await _fetchAndPersistFromStorage(
      kind: kind,
      imageKey: imageKey,
      imageVersion: imageVersion,
      primaryCacheKey: primaryCacheKey,
      recordMissingOnFailure: false,
    );
    if (updated != null) {
      _storageDisplayRefCache[primaryCacheKey] = updated;
    }
  }

  static Future<String?> _fetchAndPersistFromStorage({
    required CatalogImageKind kind,
    required String imageKey,
    required String primaryCacheKey,
    required bool recordMissingOnFailure,
    String? imageVersion,
  }) {
    return _withStorageFetchSlot(
      () => _fetchAndPersistFromStorageWithRetries(
        kind: kind,
        imageKey: imageKey,
        primaryCacheKey: primaryCacheKey,
        recordMissingOnFailure: recordMissingOnFailure,
        imageVersion: imageVersion,
      ),
    );
  }

  static Future<T> _withStorageFetchSlot<T>(Future<T> Function() run) async {
    while (_activeStorageFetches >= _storageFetchConcurrencyCap) {
      final waiter = Completer<void>();
      _storageFetchWaiters.add(waiter);
      await waiter.future;
    }
    _activeStorageFetches++;
    try {
      return await run();
    } finally {
      _activeStorageFetches--;
      if (_storageFetchWaiters.isNotEmpty) {
        _storageFetchWaiters.removeAt(0).complete();
      }
    }
  }

  static Future<String?> _fetchAndPersistFromStorageWithRetries({
    required CatalogImageKind kind,
    required String imageKey,
    required String primaryCacheKey,
    required bool recordMissingOnFailure,
    String? imageVersion,
  }) async {
    final retryLimit = _storageFetchRetryLimit;
    _ProbeOutcome? last;

    for (var attempt = 0; attempt <= retryLimit; attempt++) {
      if (attempt > 0) {
        await _delay(_retryDelayForAttempt(attempt));
      }
      last = await _probeStorageExtensions(
        kind: kind,
        imageKey: imageKey,
        primaryCacheKey: primaryCacheKey,
        imageVersion: imageVersion,
      );
      if (last.displayRef != null) {
        _noteTransportSuccess();
        return last.displayRef;
      }
      if (last.wentOffline) {
        _tripOfflineGate();
        return null;
      }
      if (last.onlyObjectNotFound) {
        break;
      }
      if (!last.sawRetryableTransport) {
        break;
      }
      // Retryable timeout / transport — continue until retry budget exhausted.
    }

    final outcome = last;
    if (outcome == null) return null;

    if (outcome.sawRetryableTransport) {
      _noteTransportFailureForKey();
    }

    if (outcome.onlyObjectNotFound && recordMissingOnFailure) {
      _storageMissingCache.add(primaryCacheKey);
      _debugLogMissingKeyOnce(kind: kind, imageKey: imageKey);
    }
    _traceResolution(
      imageKey: imageKey,
      kind: kind,
      phase: 'storage',
      storageSkipped: false,
      outcome: 'storage_miss',
    );
    return null;
  }

  static Future<_ProbeOutcome> _probeStorageExtensions({
    required CatalogImageKind kind,
    required String imageKey,
    required String primaryCacheKey,
    String? imageVersion,
  }) async {
    var sawOnlyObjectNotFound = true;
    var sawRetryableTransport = false;
    var wentOffline = false;
    final useOverride = getDownloadUrlOverride != null;
    Reference? storageRoot;

    for (final ext in assetExtensions) {
      final path = storageObjectPath(
        kind: kind,
        imageKey: imageKey,
        extension: ext,
      );
      try {
        storageExtensionProbeCount++;
        final String rawUrl;
        if (useOverride) {
          final resolved = await getDownloadUrlOverride!(path);
          if (resolved == null || resolved.isEmpty) {
            continue;
          }
          rawUrl = resolved;
        } else {
          storageRoot ??= FirebaseStorage.instance.ref();
          rawUrl = await storageRoot
              .child(path)
              .getDownloadURL()
              .timeout(storageUrlTimeout);
        }
        final url = CatalogImageVersion.appendQueryParam(rawUrl, imageVersion);
        final localPath = await CatalogImageDiskCache.persistFromUrl(
          kind: kind,
          imageKey: imageKey,
          imageVersion: imageVersion,
          downloadUrl: rawUrl,
          extension: ext,
        );
        final displayRef = localPath ?? url;
        _storageDisplayRefCache[primaryCacheKey] = displayRef;
        _storageMissingCache.remove(primaryCacheKey);
        _traceResolution(
          imageKey: imageKey,
          kind: kind,
          phase: 'storage',
          attemptedPath: path,
          hit: true,
          storageSkipped: false,
          outcome: localPath != null ? 'disk_cache_persisted' : 'storage_url',
        );
        return _ProbeOutcome(displayRef: displayRef);
      } on TimeoutException {
        sawOnlyObjectNotFound = false;
        sawRetryableTransport = true;
        _traceResolution(
          imageKey: imageKey,
          kind: kind,
          phase: 'storage',
          attemptedPath: path,
          hit: false,
          storageSkipped: false,
          outcome: 'storage_timeout',
        );
        if (!await _isLikelyOnline()) {
          wentOffline = true;
          return _ProbeOutcome(
            wentOffline: true,
            sawRetryableTransport: true,
          );
        }
        continue;
      } on FirebaseException catch (e) {
        if (_isObjectNotFound(e)) continue;
        if (e.code == 'no-app') {
          return const _ProbeOutcome(onlyObjectNotFound: false);
        }
        if (_isTransportFailure(e)) {
          sawOnlyObjectNotFound = false;
          sawRetryableTransport = true;
          _traceResolution(
            imageKey: imageKey,
            kind: kind,
            phase: 'storage',
            attemptedPath: path,
            hit: false,
            storageSkipped: false,
            outcome: 'storage_transport_error',
          );
          if (!await _isLikelyOnline()) {
            return _ProbeOutcome(
              wentOffline: true,
              sawRetryableTransport: true,
            );
          }
          // Abort remaining extensions for this attempt; outer loop may retry.
          return _ProbeOutcome(sawRetryableTransport: true);
        }
        sawOnlyObjectNotFound = false;
        return const _ProbeOutcome(onlyObjectNotFound: false);
      } on Object {
        sawOnlyObjectNotFound = false;
        return const _ProbeOutcome(onlyObjectNotFound: false);
      }
    }

    return _ProbeOutcome(
      onlyObjectNotFound: sawOnlyObjectNotFound,
      sawRetryableTransport: sawRetryableTransport,
      wentOffline: wentOffline,
    );
  }

  /// Returns false when Storage probes should be skipped (offline / paused).
  static Future<bool> _allowStorageTransport({
    required CatalogImageKind kind,
    required String imageKey,
  }) async {
    if (_storageTransportUnavailable) {
      final online = await _isLikelyOnline();
      if (_transportGateReason == _TransportGateReason.offline) {
        if (!online) {
          _traceResolution(
            imageKey: imageKey,
            kind: kind,
            phase: 'storage',
            storageSkipped: true,
            outcome: 'skipped_transport_unavailable',
          );
          return false;
        }
        _clearTransportGate();
      } else if (_transportGateReason ==
          _TransportGateReason.consecutiveFailures) {
        final until = _transportGateUntil;
        final expired = until == null || !_now().isBefore(until);
        if (!expired) {
          _traceResolution(
            imageKey: imageKey,
            kind: kind,
            phase: 'storage',
            storageSkipped: true,
            outcome: 'skipped_transport_unavailable',
          );
          return false;
        }
        // TTL elapsed — reopen; offline check below may re-trip if needed.
        _clearTransportGate();
      } else {
        _clearTransportGate();
      }
    }

    if (!await _isLikelyOnline()) {
      _tripOfflineGate();
      _traceResolution(
        imageKey: imageKey,
        kind: kind,
        phase: 'storage',
        storageSkipped: true,
        outcome: 'skipped_offline',
      );
      return false;
    }
    return true;
  }

  static void _noteTransportSuccess() {
    _consecutiveTransportFailures = 0;
    if (_transportGateReason != _TransportGateReason.offline) {
      _clearTransportGate();
    }
  }

  static void _noteTransportFailureForKey() {
    _consecutiveTransportFailures++;
    if (_consecutiveTransportFailures >=
        consecutiveTransportFailuresToTripGate) {
      _tripConsecutiveFailureGate();
    }
  }

  static void _tripOfflineGate() {
    _storageTransportUnavailable = true;
    _transportGateReason = _TransportGateReason.offline;
    _transportGateUntil = null;
  }

  static void _tripConsecutiveFailureGate() {
    _storageTransportUnavailable = true;
    _transportGateReason = _TransportGateReason.consecutiveFailures;
    _transportGateUntil = _now().add(transportGateTtl);
  }

  static void _clearTransportGate() {
    _storageTransportUnavailable = false;
    _transportGateReason = _TransportGateReason.none;
    _transportGateUntil = null;
    _consecutiveTransportFailures = 0;
  }

  static DateTime _now() => nowOverride?.call() ?? DateTime.now();

  static Future<void> _delay(Duration duration) {
    final override = delayOverride;
    if (override != null) return override(duration);
    return Future<void>.delayed(duration);
  }

  static Duration _retryDelayForAttempt(int attempt) {
    final delays = storageRetryDelaysOverride ?? storageRetryDelays;
    final index = (attempt - 1).clamp(0, delays.length - 1);
    final base = delays[index];
    // Small deterministic-ish jitter from probe count so retries do not sync.
    final jitterMs = (storageExtensionProbeCount * 37) % 120;
    return base + Duration(milliseconds: jitterMs);
  }

  static Future<bool> _isLikelyOnline() async {
    final override = isOnlineOverride;
    if (override != null) return override();
    // Download-URL test harness must not depend on platform connectivity.
    if (getDownloadUrlOverride != null) return true;
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } on Object {
      // Connectivity probe failed — stay optimistic and let Storage decide.
      return true;
    }
  }

  static bool _isTransportFailure(FirebaseException e) {
    final code = e.code.toLowerCase();
    if (code == 'unavailable' ||
        code == 'deadline-exceeded' ||
        code == 'network-request-failed' ||
        code == 'retry-limit-exceeded' ||
        code == 'canceled') {
      return true;
    }
    final msg = (e.message ?? '').toLowerCase();
    return msg.contains('network') ||
        msg.contains('unreachable') ||
        msg.contains('timed out') ||
        msg.contains('timeout');
  }

  static void _traceResolution({
    required String imageKey,
    required CatalogImageKind kind,
    required String phase,
    String? attemptedPath,
    bool? hit,
    bool? storageSkipped,
    String? outcome,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      'CatalogImageResolver[$phase] imageKey="$imageKey" kind=${kind.name} '
      'path=${attemptedPath ?? '-'} hit=${hit ?? '-'} '
      'storageSkipped=${storageSkipped ?? '-'} outcome=${outcome ?? '-'}',
    );
  }

  static bool _isObjectNotFound(FirebaseException e) {
    final code = e.code.toLowerCase();
    if (code == 'object-not-found' || code == 'not-found' || code == '404') {
      return true;
    }
    final msg = (e.message ?? '').toLowerCase();
    // Android StorageException sometimes surfaces only as "-13010 / 404".
    return msg.contains('not found') ||
        msg.contains('"code": 404') ||
        msg.contains('"code":404') ||
        msg.contains('-13010');
  }

  static void _debugLogMissingKeyOnce({
    required CatalogImageKind kind,
    required String imageKey,
  }) {
    if (!kDebugMode) return;
    final marker = '${kind.name}:$imageKey';
    if (_debugLoggedMissingKeys.contains(marker)) return;
    _debugLoggedMissingKeys.add(marker);
    debugPrint(
      'CatalogImageResolver: missing Storage asset for '
      '${kind.name} imageKey="$imageKey" (all extensions probed).',
    );
  }

  /// Debug helper to inspect all missing Storage image keys seen this session.
  ///
  /// Output is grouped by kind (`series` / `figure`) and sorted for quick
  /// copy/paste into backfill scripts. No-op outside debug mode.
  static void debugDumpMissingKeys() {
    if (!kDebugMode) return;
    if (_debugLoggedMissingKeys.isEmpty) {
      debugPrint(
        'CatalogImageResolver: no missing Storage image keys recorded.',
      );
      return;
    }

    final grouped = <String, List<String>>{};
    for (final marker in _debugLoggedMissingKeys) {
      final sep = marker.indexOf(':');
      if (sep <= 0 || sep >= marker.length - 1) continue;
      final kind = marker.substring(0, sep);
      final key = marker.substring(sep + 1);
      grouped.putIfAbsent(kind, () => <String>[]).add(key);
    }
    for (final keys in grouped.values) {
      keys.sort();
    }

    debugPrint('CatalogImageResolver: missing Storage image keys snapshot:');
    for (final kind in <String>['series', 'figure']) {
      final keys = grouped[kind];
      if (keys == null || keys.isEmpty) continue;
      debugPrint('  $kind (${keys.length}): ${keys.join(', ')}');
    }
  }

  static bool get _firebaseStorageReady {
    if (firebaseStorageReadyOverride != null) {
      return firebaseStorageReadyOverride!;
    }
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Derive an [imageKey] from legacy seed/Firestore `thumbnailAsset` paths.
  /// Returns empty when [legacyThumbnailAsset] is null/blank/non-filesystem path / URL.
  static String imageKeyFromLegacyThumbnailAsset(String? legacyThumbnailAsset) {
    final raw = legacyThumbnailAsset?.trim();
    if (raw == null || raw.isEmpty) return '';
    final lower = raw.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return '';
    final posix = raw.replaceAll(r'\', '/');
    final parts = posix.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    final last = parts.last;
    final stem = last.replaceFirst(
      RegExp(r'\.(avif|webp|png|jpe?g|jpeg)$', caseSensitive: false),
      '',
    );
    return stem.trim();
  }
}

final class _StaleRefreshJob {
  const _StaleRefreshJob({
    required this.kind,
    required this.imageKey,
    required this.primaryCacheKey,
    this.imageVersion,
  });

  final CatalogImageKind kind;
  final String imageKey;
  final String? imageVersion;
  final String primaryCacheKey;
}

final class _ProbeOutcome {
  const _ProbeOutcome({
    this.displayRef,
    this.onlyObjectNotFound = false,
    this.sawRetryableTransport = false,
    this.wentOffline = false,
  });

  final String? displayRef;
  final bool onlyObjectNotFound;
  final bool sawRetryableTransport;
  final bool wentOffline;
}

enum _TransportGateReason { none, offline, consecutiveFailures }

/// Catalog art subtree — maps to `catalog/series/` or `catalog/figures/` in Storage.
enum CatalogImageKind { series, figure }
