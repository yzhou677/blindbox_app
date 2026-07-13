import 'dart:convert';

import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/series_completion_resolution.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_display_stats.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_record.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_shelf_progress_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

/// Existing-user upgrade smoke: legacy reveal prefs + display stats fallback.
///
/// Verification only — fixtures simulate store upgrades, not new installs.

final class _UpgradeSnapNotifier extends CollectionNotifier {
  _UpgradeSnapNotifier(this._snap);
  final CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;
}

const _emptyCatalog = CatalogSeedBundle(
  brands: [],
  ips: [],
  series: [],
  figures: [],
);

TrackedFigure _owned(String id) => TrackedFigure(
      figureId: id,
      state: FigureCollectionState.owned,
    );

/// Scenario 1 shelf: regular-complete + master-complete + incomplete.
CollectionSnapshot upgradeMixedShelf() {
  final regularOnly = testShelfSeries(
    id: 's_regular',
    name: 'Regular Only',
    figures: const [
      ShelfFigure(
        id: 'r0',
        seriesId: 's_regular',
        name: 'R',
        rarity: 'Regular',
        isSecret: false,
      ),
    ],
  );
  final master = testShelfSeries(
    id: 's_master',
    name: 'Master Series',
    figures: const [
      ShelfFigure(
        id: 'm0',
        seriesId: 's_master',
        name: 'R',
        rarity: 'Regular',
        isSecret: false,
      ),
      ShelfFigure(
        id: 'm_sec',
        seriesId: 's_master',
        name: 'S',
        rarity: 'Secret',
        isSecret: true,
      ),
    ],
  );
  final partial = testShelfSeries(
    id: 's_partial',
    name: 'Partial',
    figures: const [
      ShelfFigure(
        id: 'p0',
        seriesId: 's_partial',
        name: 'A',
        rarity: 'Regular',
        isSecret: false,
      ),
      ShelfFigure(
        id: 'p1',
        seriesId: 's_partial',
        name: 'B',
        rarity: 'Regular',
        isSecret: false,
      ),
    ],
  );
  return CollectionSnapshot(
    shelfSeries: [regularOnly, master, partial],
    figureStates: {
      'r0': _owned('r0'),
      'm0': _owned('m0'),
      'm_sec': _owned('m_sec'),
      'p0': _owned('p0'),
      // p1 missing → 50% regular progress
    },
  );
}

/// Scenario 6: no Secret-bearing series.
CollectionSnapshot noSecretShelf() {
  final a = testShelfSeries(
    id: 'a',
    figures: const [
      ShelfFigure(
        id: 'a0',
        seriesId: 'a',
        name: 'A',
        rarity: 'Regular',
        isSecret: false,
      ),
    ],
  );
  final b = testShelfSeries(
    id: 'b',
    figures: const [
      ShelfFigure(
        id: 'b0',
        seriesId: 'b',
        name: 'B',
        rarity: 'Regular',
        isSecret: false,
      ),
      ShelfFigure(
        id: 'b1',
        seriesId: 'b',
        name: 'B2',
        rarity: 'Regular',
        isSecret: false,
      ),
    ],
  );
  return CollectionSnapshot(
    shelfSeries: [a, b],
    figureStates: {
      'a0': _owned('a0'),
      'b0': _owned('b0'),
    },
  );
}

/// Scenario 7: 5 series — 3 without Secrets, 2 Secret-bearing Master Complete.
CollectionSnapshot fullyMasteredSecretShelf() {
  ShelfSeries noSecret(String id) => testShelfSeries(
        id: id,
        name: id,
        figures: [
          ShelfFigure(
            id: '${id}_r',
            seriesId: id,
            name: 'R',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
      );
  ShelfSeries withSecret(String id) => testShelfSeries(
        id: id,
        name: id,
        figures: [
          ShelfFigure(
            id: '${id}_r',
            seriesId: id,
            name: 'R',
            rarity: 'Regular',
            isSecret: false,
          ),
          ShelfFigure(
            id: '${id}_s',
            seriesId: id,
            name: 'S',
            rarity: 'Secret',
            isSecret: true,
          ),
        ],
      );

  final series = [
    noSecret('ns1'),
    noSecret('ns2'),
    noSecret('ns3'),
    withSecret('sec1'),
    withSecret('sec2'),
  ];
  final states = <String, TrackedFigure>{};
  for (final s in series) {
    for (final f in s.figures) {
      states[f.id] = _owned(f.id);
    }
  }
  return CollectionSnapshot(shelfSeries: series, figureStates: states);
}

String _legacyMemoryJson({
  required String archetypeId,
  required String signatureHash,
  required Map<String, dynamic> statsMap,
  int? statsVersion,
  String reasonKey = 'deepCompletion',
  String resolverVersion = kCollectorTypeResolverVersion,
  int revealedAtMs = 1717200000000,
}) {
  final map = <String, dynamic>{
    'collectorTypeArchetypeId': archetypeId,
    'collectorTypeRevealedAtMs': revealedAtMs,
    'collectorTypeSignatureHash': signatureHash,
    'collectorTypeStatsJson': jsonEncode(statsMap),
    'collectorTypeReasonKey': reasonKey,
    'collectorTypeResolverVersion': resolverVersion,
    'collectorTypeRevealHistory': [
      {
        'archetypeId': archetypeId,
        'revealedAtMs': revealedAtMs,
        'signatureHash': signatureHash,
        'reasonKey': reasonKey,
        'score': 20.0,
        'confidence': 0.4,
        'resolverVersion': resolverVersion,
      },
    ],
  };
  if (statsVersion != null) {
    map['collectorTypeStatsVersion'] = statsVersion;
  }
  return jsonEncode(map);
}

Future<void> _seedLegacyPrefs(String memoryJson) async {
  SharedPreferences.setMockInitialValues({
    'collection_memory_v3': memoryJson,
  });
  CollectionMemoryStore.instance.resetForTest();
  await CollectionMemoryStore.instance.reloadFromPrefsForTest();
}

Future<String?> _prefsRaw() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('collection_memory_v3');
}

ProviderContainer _containerFor(CollectionSnapshot snap) {
  return ProviderContainer(
    overrides: [
      collectionNotifierProvider.overrideWith(() => _UpgradeSnapNotifier(snap)),
      catalogBundleProvider.overrideWith((ref) async => _emptyCatalog),
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CollectionMemoryStore.instance.resetForTest();
  });

  group('Upgrade smoke — existing-user path', () {
    test('S1 legacy reveal (no stats version) live-derives + needsReveal',
        () async {
      final snap = upgradeMixedShelf();
      final expected = aggregateShelfCompletion(snap);
      expect(expected.completedSeriesCount, 2);
      expect(expected.masterCompleteSeriesCount, 1);
      expect(expected.masterEligibleSeriesCount, 1);
      expect(expected.regularCompletionPercent, 83);
      expect(expected.masterCompletionPercent, 100);

      final sig = computeCollectorTypeSignatureHash(snap);
      await _seedLegacyPrefs(
        _legacyMemoryJson(
          archetypeId: CollectorTypeArchetypeId.hunter.name,
          signatureHash: sig,
          // Pre-v2 payload: no tier keys, no version stamp.
          statsMap: {
            'totalOwned': 4,
            'totalWishlist': 0,
            'trackedSeries': 3,
            'completionPercent': 40,
            'secretOwned': 0,
            'secretSlots': 0,
            'brandBreakdown': <String, int>{},
            'topSeries': <String>[],
            'customSeriesRatio': 0,
          },
        ),
      );

      final versionBefore =
          CollectionMemoryStore.instance.cached.collectorTypeStatsVersion;
      final prefsBefore = await _prefsRaw();
      expect(versionBefore, isNull);

      final container = _containerFor(snap);
      addTearDown(container.dispose);

      final identity = container.read(collectorTypeIdentityProvider);
      final display = container.read(collectorTypeDisplayStatsProvider)!;
      final needsReveal = container.read(collectorTypeNeedsRevealProvider);

      expect(identity!.archetypeId, CollectorTypeArchetypeId.hunter);
      expect(display.completedSeriesCount, 2);
      expect(display.masterCompleteSeriesCount, 1);
      expect(display.masterEligibleSeriesCount, 1);
      expect(display.completionPercent, 83);
      expect(
        ShelfProgressPresentation.masterCompletionPercent(display),
        100,
      );
      expect(needsReveal, isTrue);

      // Identity frozen stats remain the decoded legacy zeros / old %.
      expect(identity.stats.completedSeriesCount, 0);
      expect(identity.stats.completionPercent, 40);

      final prefsAfter = await _prefsRaw();
      expect(prefsAfter, prefsBefore);
      expect(
        CollectionMemoryStore.instance.cached.collectorTypeStatsVersion,
        isNull,
      );
    });

    test('S2 mixed-version stats: no false 0% Master Completion', () async {
      final snap = upgradeMixedShelf();
      final expected = aggregateShelfCompletion(snap);
      final sig = computeCollectorTypeSignatureHash(snap);

      await _seedLegacyPrefs(
        _legacyMemoryJson(
          archetypeId: CollectorTypeArchetypeId.completionist.name,
          signatureHash: sig,
          statsVersion: 1,
          statsMap: {
            'totalOwned': 4,
            'trackedSeries': 3,
            'completedSeriesCount': 2,
            'masterCompleteSeriesCount': 1,
            // masterEligibleSeriesCount intentionally missing
            'completionPercent': 70,
            'secretOwned': 1,
            'secretSlots': 1,
            'brandBreakdown': <String, int>{},
            'topSeries': <String>[],
            'customSeriesRatio': 0,
          },
        ),
      );

      final prefsBefore = await _prefsRaw();
      final container = _containerFor(snap);
      addTearDown(container.dispose);

      final identity = container.read(collectorTypeIdentityProvider)!;
      // Naïve decode would treat missing eligible as 0 → 0% Master.
      expect(identity.stats.masterCompleteSeriesCount, 1);
      expect(identity.stats.masterEligibleSeriesCount, 0);
      expect(
        ShelfProgressPresentation.masterCompletionPercent(identity.stats),
        0,
      );

      final display = container.read(collectorTypeDisplayStatsProvider)!;
      expect(display.masterEligibleSeriesCount, expected.masterEligibleSeriesCount);
      expect(
        ShelfProgressPresentation.masterCompletionPercent(display),
        expected.masterCompletionPercent,
      );
      expect(display.masterEligibleSeriesCount, greaterThan(0));
      expect(container.read(collectorTypeNeedsRevealProvider), isTrue);
      expect(await _prefsRaw(), prefsBefore);
    });

    test('S3 current v2 stats: frozen path, needsReveal false', () async {
      final snap = upgradeMixedShelf();
      final live = buildCollectorTypeStats(snap, interpretShelf(snap), null);
      final sig = computeCollectorTypeSignatureHash(snap);

      await _seedLegacyPrefs(
        _legacyMemoryJson(
          archetypeId: CollectorTypeArchetypeId.completionist.name,
          signatureHash: sig,
          statsVersion: kCollectorTypeStatsVersion,
          statsMap: live.toJson(),
          reasonKey: CollectorTypeReasonKey.deepCompletion.name,
        ),
      );

      final container = _containerFor(snap);
      addTearDown(container.dispose);

      final identity = container.read(collectorTypeIdentityProvider)!;
      final display = container.read(collectorTypeDisplayStatsProvider)!;

      expect(identical(display, identity.stats), isTrue);
      expect(display.completedSeriesCount, live.completedSeriesCount);
      expect(display.masterEligibleSeriesCount, live.masterEligibleSeriesCount);
      expect(display.completionPercent, live.completionPercent);
      expect(container.read(collectorTypeNeedsRevealProvider), isFalse);
      expect(
        CollectionMemoryStore.instance.cached.collectorTypeStatsVersion,
        kCollectorTypeStatsVersion,
      );
    });

    test('S4 outdated stats + Reveal again settles without loop', () async {
      final snap = upgradeMixedShelf();
      final expected = aggregateShelfCompletion(snap);
      final sig = computeCollectorTypeSignatureHash(snap);
      final liveBefore = resolveCollectorType(
        snapshot: snap,
        profile: interpretShelf(snap),
      );

      await _seedLegacyPrefs(
        _legacyMemoryJson(
          // Intentionally not the live winner — formal Reveal must refresh.
          archetypeId: CollectorTypeArchetypeId.wanderer.name,
          signatureHash: sig,
          reasonKey: CollectorTypeReasonKey.stillUnfolding.name,
          statsMap: {
            'trackedSeries': 3,
            'completionPercent': 40,
            'secretOwned': 0,
            'secretSlots': 0,
            'brandBreakdown': <String, int>{},
            'topSeries': <String>[],
            'customSeriesRatio': 0,
          },
        ),
      );

      final versionBefore =
          CollectionMemoryStore.instance.cached.collectorTypeStatsVersion;
      expect(versionBefore, isNull);

      final container = _containerFor(snap);
      addTearDown(container.dispose);

      expect(container.read(collectorTypeIdentityProvider)!.archetypeId,
          CollectorTypeArchetypeId.wanderer);
      expect(container.read(collectorTypeNeedsRevealProvider), isTrue);

      await container
          .read(collectorTypeViewModelProvider.notifier)
          .requestReveal();

      final identity = container.read(collectorTypeIdentityProvider)!;
      final display = container.read(collectorTypeDisplayStatsProvider)!;
      final memory = CollectionMemoryStore.instance.cached;

      expect(memory.collectorTypeStatsVersion, kCollectorTypeStatsVersion);
      expect(identity.stats.completedSeriesCount, expected.completedSeriesCount);
      expect(
        identity.stats.masterCompleteSeriesCount,
        expected.masterCompleteSeriesCount,
      );
      expect(
        identity.stats.masterEligibleSeriesCount,
        expected.masterEligibleSeriesCount,
      );
      expect(identity.stats.completionPercent, expected.regularCompletionPercent);
      expect(display.completionPercent, expected.regularCompletionPercent);
      expect(
        ShelfProgressPresentation.masterCompletionPercent(display),
        expected.masterCompletionPercent,
      );
      expect(container.read(collectorTypeNeedsRevealProvider), isFalse);
      // Formal refresh: resolver candidate, not Still of wanderer.
      expect(identity.archetypeId, liveBefore.archetypeId);
      expect(identity.archetypeId, isNot(CollectorTypeArchetypeId.wanderer));

      // Second reveal must not re-arm needsReveal.
      await container
          .read(collectorTypeViewModelProvider.notifier)
          .requestReveal();
      expect(container.read(collectorTypeNeedsRevealProvider), isFalse);
    });

    test('S5 identity frozen while stats heal for display', () async {
      final snap = upgradeMixedShelf();
      final sig = computeCollectorTypeSignatureHash(snap);
      final live = resolveCollectorType(
        snapshot: snap,
        profile: interpretShelf(snap),
      );

      await _seedLegacyPrefs(
        _legacyMemoryJson(
          archetypeId: CollectorTypeArchetypeId.hunter.name,
          signatureHash: sig,
          reasonKey: CollectorTypeReasonKey.manySecrets.name,
          statsMap: {
            'trackedSeries': 3,
            'completionPercent': 12,
            'secretOwned': 0,
            'secretSlots': 1,
            'brandBreakdown': <String, int>{},
            'topSeries': <String>[],
            'customSeriesRatio': 0,
          },
        ),
      );

      final prefsBefore = await _prefsRaw();
      final container = _containerFor(snap);
      addTearDown(container.dispose);

      final identity = container.read(collectorTypeIdentityProvider)!;
      final display = container.read(collectorTypeDisplayStatsProvider)!;

      expect(identity.archetypeId, CollectorTypeArchetypeId.hunter);
      // Live candidate may differ — must not silently rewrite identity.
      if (live.archetypeId != CollectorTypeArchetypeId.hunter) {
        expect(
          container.read(collectorTypeCandidateArchetypeProvider),
          live.archetypeId,
        );
        expect(identity.archetypeId, isNot(live.archetypeId));
      }
      expect(display.completedSeriesCount, greaterThan(0));
      expect(display.completionPercent, isNot(12));
      expect(await _prefsRaw(), prefsBefore);
      expect(
        CollectionMemoryStore.instance.cached.collectorTypeArchetypeId,
        CollectorTypeArchetypeId.hunter.name,
      );
    });

    test('S6 no Secret-bearing series: omit Master row, no NaN', () async {
      final snap = noSecretShelf();
      final expected = aggregateShelfCompletion(snap);
      expect(expected.masterEligibleSeriesCount, 0);
      expect(expected.masterCompletionPercent, 0);

      final sig = computeCollectorTypeSignatureHash(snap);
      await _seedLegacyPrefs(
        _legacyMemoryJson(
          archetypeId: CollectorTypeArchetypeId.minimalist.name,
          signatureHash: sig,
          statsMap: {
            'trackedSeries': 2,
            'completionPercent': 50,
            'secretOwned': 0,
            'secretSlots': 0,
            'brandBreakdown': <String, int>{},
            'topSeries': <String>[],
            'customSeriesRatio': 0,
          },
        ),
      );

      final container = _containerFor(snap);
      addTearDown(container.dispose);

      final display = container.read(collectorTypeDisplayStatsProvider)!;
      expect(display.masterEligibleSeriesCount, 0);
      expect(display.masterCompleteSeriesCount, 0);
      expect(display.completionPercent, expected.regularCompletionPercent);
      expect(display.completionPercent.isNaN, isFalse);
      expect(
        ShelfProgressPresentation.masterCompletionRatio(display).isNaN,
        isFalse,
      );
      expect(
        ShelfProgressPresentation.showMasterCompletion(display),
        isFalse,
      );
      expect(container.read(collectorTypeNeedsRevealProvider), isTrue);
    });

    test('S7 Secret-eligible shelf fully mastered: Master 2/2 = 100%',
        () async {
      final snap = fullyMasteredSecretShelf();
      final expected = aggregateShelfCompletion(snap);
      expect(snap.shelfSeries, hasLength(5));
      expect(expected.masterEligibleSeriesCount, 2);
      expect(expected.masterCompleteSeriesCount, 2);
      expect(expected.masterCompletionPercent, 100);
      // All five series Regular-complete → Regular Completion 100%.
      expect(expected.regularCompletionPercent, 100);
      expect(expected.completedSeriesCount, 5);

      final live = buildCollectorTypeStats(snap, interpretShelf(snap), null);
      final sig = computeCollectorTypeSignatureHash(snap);
      await _seedLegacyPrefs(
        _legacyMemoryJson(
          archetypeId: CollectorTypeArchetypeId.completionist.name,
          signatureHash: sig,
          statsVersion: kCollectorTypeStatsVersion,
          statsMap: live.toJson(),
        ),
      );

      final container = _containerFor(snap);
      addTearDown(container.dispose);

      final display = container.read(collectorTypeDisplayStatsProvider)!;
      expect(display.trackedSeries, 5);
      expect(display.masterEligibleSeriesCount, 2);
      expect(display.masterCompleteSeriesCount, 2);
      expect(display.completionPercent, 100);
      expect(
        ShelfProgressPresentation.masterCompletionPercent(display),
        100,
      );
      // No-secret series excluded from Master denominator.
      expect(display.masterEligibleSeriesCount, isNot(display.trackedSeries));
    });
  });

  group('Upgrade smoke — pure resolve helpers', () {
    test('resolveCollectorTypeDisplayStats does not mutate memory', () {
      final snap = upgradeMixedShelf();
      final memory = CollectionMemoryData(
        collectorTypeArchetypeId: CollectorTypeArchetypeId.hunter.name,
        collectorTypeRevealedAtMs: 1,
        collectorTypeSignatureHash: 'sig',
        collectorTypeStatsJson: jsonEncode({
          'completionPercent': 40,
          'trackedSeries': 3,
        }),
        collectorTypeStatsVersion: null,
        collectorTypeReasonKey: CollectorTypeReasonKey.manySecrets.name,
        collectorTypeResolverVersion: kCollectorTypeResolverVersion,
      );
      final identity = CollectorTypeIdentity(
        archetypeId: CollectorTypeArchetypeId.hunter,
        revealedAt: DateTime(2025, 6, 1),
        signatureHash: 'sig',
        stats: CollectorTypeStats.fromJson({
          'completionPercent': 40,
          'trackedSeries': 3,
        }),
        reasonKey: CollectorTypeReasonKey.manySecrets,
      );

      final before = memory.collectorTypeStatsJson;
      final display = resolveCollectorTypeDisplayStats(
        storedIdentity: identity,
        memory: memory,
        snapshot: snap,
        profile: interpretShelf(snap),
      );
      expect(memory.collectorTypeStatsJson, before);
      expect(display.completedSeriesCount, 2);
      expect(identity.archetypeId, CollectorTypeArchetypeId.hunter);
    });
  });
}
