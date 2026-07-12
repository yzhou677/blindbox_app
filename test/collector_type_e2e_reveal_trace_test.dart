import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_view_model.dart';
import 'package:blindbox_app/features/collection/insights/debug/collector_type_reveal_trace.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_record.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_reveal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

final class _SnapNotifier extends CollectionNotifier {
  _SnapNotifier(this._snap);
  final CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;
}

void main() {
  testWidgets('CT_TRACE needsReveal path persists Candidate (not Still)',
      (tester) async {
    final lines = <String>[];
    final previousPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null && message.contains('[CT_TRACE]')) {
        lines.add(message);
      }
      previousPrint(message, wrapWidth: wrapWidth);
    };
    addTearDown(() {
      CollectorTypeRevealTrace.activeTraceId = null;
      CollectorTypeRevealTrace.emitProviderHero = false;
    });

    try {
      SharedPreferences.setMockInitialValues({});
      CollectionMemoryStore.instance.resetForTest();

      final snap = CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(
            id: 's1',
            name: 'A',
            ipName: 'Smiski',
            taxonomyIpId: 'smiski',
            taxonomyBrandId: 'dreams',
            brand: 'Dreams',
            catalogTemplateId: 'c1',
            figures: const [
              ShelfFigure(
                id: 'f1',
                seriesId: 's1',
                name: 'A1',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
          testShelfSeries(
            id: 's2',
            name: 'B',
            ipName: 'Hirono',
            taxonomyIpId: 'hirono',
            taxonomyBrandId: 'pop_mart',
            brand: 'POP MART',
            catalogTemplateId: 'c2',
            figures: const [
              ShelfFigure(
                id: 'f2',
                seriesId: 's2',
                name: 'B1',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
          testShelfSeries(
            id: 's3',
            name: 'C',
            ipName: 'Dimoo',
            taxonomyIpId: 'dimoo',
            taxonomyBrandId: 'pop_mart',
            brand: 'POP MART',
            catalogTemplateId: 'c3',
            figures: const [
              ShelfFigure(
                id: 'f3',
                seriesId: 's3',
                name: 'C1',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
        ],
        figureStates: const {},
      );
      final signature = computeCollectorTypeSignatureHash(snap);
      final live = resolveCollectorType(
        snapshot: snap,
        profile: interpretShelf(snap),
      );
      expect(live.archetypeId, isNot(CollectorTypeArchetypeId.wanderer));

      // Same signature + old version → needsReveal (version), not signature drift.
      await CollectionMemoryStore.instance.saveCollectorType(
        CollectorTypeIdentity(
          archetypeId: CollectorTypeArchetypeId.wanderer,
          revealedAt: DateTime(2026, 7, 1),
          signatureHash: signature,
          stats: live.stats,
          reasonKey: CollectorTypeReasonKey.curiousSpread,
        ),
        revealRecord: CollectorTypeRevealRecord(
          archetypeId: CollectorTypeArchetypeId.wanderer,
          revealedAt: DateTime(2026, 7, 1),
          signatureHash: signature,
          reasonKey: CollectorTypeReasonKey.curiousSpread,
          score: 52,
          confidence: 0.2,
          resolverVersion: '5.1',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          collectionNotifierProvider.overrideWith(() => _SnapNotifier(snap)),
          catalogBundleProvider.overrideWith(
            (ref) async => const CatalogSeedBundle(
              brands: [],
              ips: [],
              series: [],
              figures: [],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: CollectorTypeRevealCard()),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(container.read(collectorTypeNeedsRevealProvider), isTrue);

      final revealFuture = container
          .read(collectorTypeViewModelProvider.notifier)
          .requestReveal();
      await tester.pump();
      await tester
          .pump(Duration(milliseconds: collectorTypeAnalyzingHoldMs + 100));
      await revealFuture;
      await tester.pump();

      final stage4 =
          lines.firstWhere((l) => l.contains('stage=4_identity_creation'));
      expect(stage4, contains('branch=Candidate'));
      expect(stage4, contains('needsReveal=true'));

      final revealed = container.read(collectorTypeViewModelProvider);
      expect(
        (revealed as CollectorTypeRevealRevealed).identity.archetypeId,
        live.archetypeId,
      );
    } finally {
      // Restore before test invariants check (tearDown runs too late).
      debugPrint = previousPrint;
    }
  });
}
