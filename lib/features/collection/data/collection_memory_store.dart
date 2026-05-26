import 'dart:convert';

import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/application/collection_evolution_interpreter.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/shelf_era.dart';
import 'package:blindbox_app/features/collection/domain/shelf_mood.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted collection journey milestones (offline, lightweight).
@immutable
class CollectionMemoryData {
  const CollectionMemoryData({
    this.firstSecretOwnedAtMs,
    this.lastCompletedSeriesId,
    this.lastCompletedAtMs,
    this.firstSeriesAddedAtMs,
    this.lastRecordedEra,
    this.priorEraForEvolution,
    this.priorEraSetAtMs,
    this.ipSeriesDepth = const {},
    this.collectorTypeArchetypeId,
    this.collectorTypeRevealedAtMs,
    this.collectorTypeSignatureHash,
    this.collectorTypeStatsJson,
    this.collectorTypeStatsVersion,
  });

  final int? firstSecretOwnedAtMs;
  final String? lastCompletedSeriesId;
  final int? lastCompletedAtMs;
  final int? firstSeriesAddedAtMs;
  final ShelfEra? lastRecordedEra;
  final ShelfEra? priorEraForEvolution;
  final int? priorEraSetAtMs;

  /// Taxonomy IP id → count of series added over time (depth, not social score).
  final Map<String, int> ipSeriesDepth;

  /// Persisted collector type (stable until user re-reveals).
  final String? collectorTypeArchetypeId;
  final int? collectorTypeRevealedAtMs;
  final String? collectorTypeSignatureHash;
  final String? collectorTypeStatsJson;
  final int? collectorTypeStatsVersion;

  CollectorTypeIdentity? get collectorTypeIdentity {
    final idName = collectorTypeArchetypeId;
    if (idName == null || idName.isEmpty) return null;
    final revealedMs = collectorTypeRevealedAtMs;
    if (revealedMs == null) return null;
    try {
      final statsRaw = collectorTypeStatsJson;
      final statsMap = statsRaw != null && statsRaw.isNotEmpty
          ? jsonDecode(statsRaw) as Map<String, dynamic>
          : <String, dynamic>{};
      return CollectorTypeIdentity.fromJson({
        'archetypeId': idName,
        'revealedAtMs': revealedMs,
        'signatureHash': collectorTypeSignatureHash ?? '',
        'stats': statsMap,
      });
    } catch (_) {
      return null;
    }
  }

  DateTime? get priorEraSetAt => priorEraSetAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(priorEraSetAtMs!);

  DateTime? get firstSecretOwnedAt => firstSecretOwnedAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(firstSecretOwnedAtMs!);

  DateTime? get lastCompletedAt => lastCompletedAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(lastCompletedAtMs!);

  DateTime? get firstSeriesAddedAt => firstSeriesAddedAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(firstSeriesAddedAtMs!);
}

/// Local prefs backing for shelf memory moments.
final class CollectionMemoryStore {
  CollectionMemoryStore._();

  static final CollectionMemoryStore instance = CollectionMemoryStore._();

  static const _prefsKeyV3 = 'collection_memory_v3';
  static const _prefsKeyV2 = 'collection_memory_v2';
  static const _prefsKeyV1 = 'collection_memory_v1';

  CollectionMemoryData _cached = const CollectionMemoryData();
  bool _loaded = false;

  CollectionMemoryData get cached {
    if (!_loaded) return const CollectionMemoryData();
    return _cached;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final rawV3 = prefs.getString(_prefsKeyV3);
    if (rawV3 != null && rawV3.isNotEmpty) {
      _cached = _decode(rawV3);
    } else {
      final rawV2 = prefs.getString(_prefsKeyV2);
      if (rawV2 != null && rawV2.isNotEmpty) {
        _cached = _decode(rawV2);
      } else {
        final rawV1 = prefs.getString(_prefsKeyV1);
        if (rawV1 != null && rawV1.isNotEmpty) {
          _cached = _decodeV1(rawV1);
        }
      }
    }
    _loaded = true;
  }

  Future<void> saveCollectorType(CollectorTypeIdentity identity) async {
    await ensureLoaded();
    _cached = _copy(
      _cached,
      collectorTypeArchetypeId: identity.archetypeId.name,
      collectorTypeRevealedAtMs: identity.revealedAt.millisecondsSinceEpoch,
      collectorTypeSignatureHash: identity.signatureHash,
      collectorTypeStatsJson: jsonEncode(identity.stats.toJson()),
      collectorTypeStatsVersion: 1,
    );
    await _persist();
  }

  Future<void> clearCollectorType() async {
    await ensureLoaded();
    _cached = _copy(
      _cached,
      collectorTypeArchetypeId: '',
      collectorTypeRevealedAtMs: 0,
      collectorTypeSignatureHash: '',
      collectorTypeStatsJson: '',
      collectorTypeStatsVersion: 0,
    );
    await _persist();
  }

  Future<void> recordTransitions({
    required CollectionSnapshot previous,
    required CollectionSnapshot next,
  }) async {
    await ensureLoaded();
    var data = _cached;
    var changed = false;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (data.firstSeriesAddedAtMs == null && previous.shelfSeries.isEmpty &&
        next.shelfSeries.isNotEmpty) {
      data = _copy(
        data,
        firstSeriesAddedAtMs: now,
      );
      changed = true;
    }

    final prevIds = previous.shelfSeries.map((s) => s.id).toSet();
    var depth = Map<String, int>.from(data.ipSeriesDepth);
    for (final series in next.shelfSeries) {
      if (prevIds.contains(series.id)) continue;
      final ip = series.taxonomyIpId?.trim();
      if (ip == null || ip.isEmpty) continue;
      depth[ip] = (depth[ip] ?? 0) + 1;
      changed = true;
    }
    if (depth != data.ipSeriesDepth) {
      data = _copy(data, ipSeriesDepth: depth);
    }

    if (data.firstSecretOwnedAtMs == null && _hasOwnedSecret(next)) {
      data = _copy(data, firstSecretOwnedAtMs: now);
      changed = true;
    }

    for (final series in next.shelfSeries) {
      if (!_wasSeriesComplete(previous, series.id) &&
          _isSeriesComplete(next, series.id)) {
        data = _copy(
          data,
          lastCompletedSeriesId: series.id,
          lastCompletedAtMs: now,
        );
        changed = true;
        break;
      }
    }

    final era = _eraFromSnapshot(next);
    if (era != null && !_erasEqual(era, data.lastRecordedEra)) {
      final prior = data.lastRecordedEra;
      data = _copy(
        data,
        lastRecordedEra: era,
        priorEraForEvolution: prior ?? data.priorEraForEvolution,
        priorEraSetAtMs: prior != null ? now : data.priorEraSetAtMs,
      );
      changed = true;
    }

    if (changed) {
      _cached = data;
      await _persist();
    }
  }

  static ShelfEra? _eraFromSnapshot(CollectionSnapshot snap) {
    if (snap.shelfSeries.isEmpty) return null;
    final profile = interpretShelf(snap);
    return shelfEraFromProfile(profile, snap.shelfSeries.length);
  }

  static bool _erasEqual(ShelfEra a, ShelfEra? b) {
    if (b == null) return false;
    return a.shelfMood == b.shelfMood &&
        a.dominantIpId == b.dominantIpId &&
        a.seriesCount == b.seriesCount &&
        a.secretOwnedCount == b.secretOwnedCount;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final era = _cached.lastRecordedEra;
    await prefs.setString(
      _prefsKeyV3,
      jsonEncode({
        'firstSecretOwnedAtMs': _cached.firstSecretOwnedAtMs,
        'lastCompletedSeriesId': _cached.lastCompletedSeriesId,
        'lastCompletedAtMs': _cached.lastCompletedAtMs,
        'firstSeriesAddedAtMs': _cached.firstSeriesAddedAtMs,
        'ipSeriesDepth': _cached.ipSeriesDepth,
        if (era != null) 'lastRecordedEra': _encodeEra(era),
        if (_cached.priorEraForEvolution != null)
          'priorEraForEvolution': _encodeEra(_cached.priorEraForEvolution!),
        'priorEraSetAtMs': _cached.priorEraSetAtMs,
        if (_cached.collectorTypeArchetypeId != null &&
            _cached.collectorTypeArchetypeId!.isNotEmpty)
          'collectorTypeArchetypeId': _cached.collectorTypeArchetypeId,
        if (_cached.collectorTypeRevealedAtMs != null)
          'collectorTypeRevealedAtMs': _cached.collectorTypeRevealedAtMs,
        if (_cached.collectorTypeSignatureHash != null &&
            _cached.collectorTypeSignatureHash!.isNotEmpty)
          'collectorTypeSignatureHash': _cached.collectorTypeSignatureHash,
        if (_cached.collectorTypeStatsJson != null &&
            _cached.collectorTypeStatsJson!.isNotEmpty)
          'collectorTypeStatsJson': _cached.collectorTypeStatsJson,
        if (_cached.collectorTypeStatsVersion != null)
          'collectorTypeStatsVersion': _cached.collectorTypeStatsVersion,
      }),
    );
  }

  static Map<String, Object?> _encodeEra(ShelfEra era) => {
        'shelfMood': era.shelfMood.name,
        'seriesCount': era.seriesCount,
        'secretOwnedCount': era.secretOwnedCount,
        'dominantIpId': era.dominantIpId,
        'recordedAtMs': era.recordedAt?.millisecondsSinceEpoch,
      };

  static CollectionMemoryData _decode(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return CollectionMemoryData(
        firstSecretOwnedAtMs: m['firstSecretOwnedAtMs'] as int?,
        lastCompletedSeriesId: m['lastCompletedSeriesId'] as String?,
        lastCompletedAtMs: m['lastCompletedAtMs'] as int?,
        firstSeriesAddedAtMs: m['firstSeriesAddedAtMs'] as int?,
        lastRecordedEra: _decodeEra(m['lastRecordedEra']),
        priorEraForEvolution: _decodeEra(m['priorEraForEvolution']),
        priorEraSetAtMs: m['priorEraSetAtMs'] as int?,
        ipSeriesDepth: _decodeDepth(m['ipSeriesDepth']),
        collectorTypeArchetypeId: m['collectorTypeArchetypeId'] as String?,
        collectorTypeRevealedAtMs: m['collectorTypeRevealedAtMs'] as int?,
        collectorTypeSignatureHash: m['collectorTypeSignatureHash'] as String?,
        collectorTypeStatsJson: m['collectorTypeStatsJson'] as String?,
        collectorTypeStatsVersion: m['collectorTypeStatsVersion'] as int?,
      );
    } catch (_) {
      return const CollectionMemoryData();
    }
  }

  static CollectionMemoryData _decodeV1(String raw) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return CollectionMemoryData(
        firstSecretOwnedAtMs: m['firstSecretOwnedAtMs'] as int?,
        lastCompletedSeriesId: m['lastCompletedSeriesId'] as String?,
        lastCompletedAtMs: m['lastCompletedAtMs'] as int?,
      );
    } catch (_) {
      return const CollectionMemoryData();
    }
  }

  static Map<String, int> _decodeDepth(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        if (e.key is String && e.value is int) e.key as String: e.value as int,
    };
  }

  static ShelfEra? _decodeEra(Object? raw) {
    if (raw is! Map) return null;
    final moodName = raw['shelfMood'] as String?;
    final mood = ShelfMood.values.asNameMap()[moodName] ?? ShelfMood.growing;
    final atMs = raw['recordedAtMs'] as int?;
    return ShelfEra(
      shelfMood: mood,
      seriesCount: (raw['seriesCount'] as int?) ?? 0,
      secretOwnedCount: (raw['secretOwnedCount'] as int?) ?? 0,
      dominantIpId: raw['dominantIpId'] as String?,
      recordedAt:
          atMs == null ? null : DateTime.fromMillisecondsSinceEpoch(atMs),
    );
  }

  static CollectionMemoryData _copy(
    CollectionMemoryData data, {
    int? firstSecretOwnedAtMs,
    String? lastCompletedSeriesId,
    int? lastCompletedAtMs,
    int? firstSeriesAddedAtMs,
    ShelfEra? lastRecordedEra,
    ShelfEra? priorEraForEvolution,
    int? priorEraSetAtMs,
    Map<String, int>? ipSeriesDepth,
    String? collectorTypeArchetypeId,
    int? collectorTypeRevealedAtMs,
    String? collectorTypeSignatureHash,
    String? collectorTypeStatsJson,
    int? collectorTypeStatsVersion,
  }) {
    return CollectionMemoryData(
      firstSecretOwnedAtMs:
          firstSecretOwnedAtMs ?? data.firstSecretOwnedAtMs,
      lastCompletedSeriesId:
          lastCompletedSeriesId ?? data.lastCompletedSeriesId,
      lastCompletedAtMs: lastCompletedAtMs ?? data.lastCompletedAtMs,
      firstSeriesAddedAtMs: firstSeriesAddedAtMs ?? data.firstSeriesAddedAtMs,
      lastRecordedEra: lastRecordedEra ?? data.lastRecordedEra,
      priorEraForEvolution:
          priorEraForEvolution ?? data.priorEraForEvolution,
      priorEraSetAtMs: priorEraSetAtMs ?? data.priorEraSetAtMs,
      ipSeriesDepth: ipSeriesDepth ?? data.ipSeriesDepth,
      collectorTypeArchetypeId: collectorTypeArchetypeId != null &&
              collectorTypeArchetypeId.isEmpty
          ? null
          : (collectorTypeArchetypeId ?? data.collectorTypeArchetypeId),
      collectorTypeRevealedAtMs: collectorTypeRevealedAtMs == 0
          ? null
          : (collectorTypeRevealedAtMs ?? data.collectorTypeRevealedAtMs),
      collectorTypeSignatureHash: collectorTypeSignatureHash != null &&
              collectorTypeSignatureHash.isEmpty
          ? null
          : (collectorTypeSignatureHash ?? data.collectorTypeSignatureHash),
      collectorTypeStatsJson: collectorTypeStatsJson != null &&
              collectorTypeStatsJson.isEmpty
          ? null
          : (collectorTypeStatsJson ?? data.collectorTypeStatsJson),
      collectorTypeStatsVersion: collectorTypeStatsVersion == 0
          ? null
          : (collectorTypeStatsVersion ?? data.collectorTypeStatsVersion),
    );
  }

  static bool _hasOwnedSecret(CollectionSnapshot snap) {
    for (final series in snap.shelfSeries) {
      for (final fig in series.figures) {
        if (fig.isSecret && snap.trackedOrDefault(fig.id).owned) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _isSeriesComplete(CollectionSnapshot snap, String seriesId) {
    for (final series in snap.shelfSeries) {
      if (series.id != seriesId) continue;
      final p = progressForSeries(series, snap.figureStates);
      return series.figureCount > 0 && p.owned >= series.figureCount;
    }
    return false;
  }

  static bool _wasSeriesComplete(CollectionSnapshot snap, String seriesId) {
    return _isSeriesComplete(snap, seriesId);
  }

  void resetForTest() {
    _cached = const CollectionMemoryData();
    _loaded = true;
  }
}
