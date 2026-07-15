import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:blindbox_app/features/collection/application/share_payload_builders/collector_type_share_payload_builder.dart';
import 'package:blindbox_app/features/collection/application/share_payload_builders/master_complete_share_payload_builder.dart';
import 'package:blindbox_app/features/collection/application/share_payload_builders/share_card_series_label.dart';
import 'package:blindbox_app/features/collection/application/share_payload_builders/shelf_share_featured_series_selector.dart';
import 'package:blindbox_app/features/collection/application/share_payload_builders/shelf_share_payload_builder.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetypes.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_stats.dart';
import 'package:blindbox_app/features/sharing/application/share_card_renderer.dart';
import 'package:blindbox_app/features/sharing/domain/share_card_payloads.dart';
import 'package:blindbox_app/features/sharing/presentation/widgets/shelfy_collector_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _stats = CollectorTypeStats(
  totalOwned: 26,
  totalWishlist: 4,
  trackedSeries: 8,
  completedSeriesCount: 4,
  masterCompleteSeriesCount: 1,
  masterEligibleSeriesCount: 3,
  completionPercent: 68,
  secretOwned: 1,
  secretSlots: 3,
  brandBreakdown: {},
  topSeries: [],
  customSeriesRatio: 0,
);

const _assetImage = ShareCardImageRef(
  kind: ShareCardImageKind.asset,
  value: 'assets/images/app_icon.png',
);

void main() {
  group('Collector Type share card smoke matrix', () {
    for (final row in _collectorMatrix) {
      testWidgets('${row.name} maps copy, asset, and lays out', (tester) async {
        final payload = buildCollectorTypeSharePayload(
          CollectorTypeIdentity(
            archetypeId: row.id,
            revealedAt: DateTime.utc(2026),
            signatureHash: 'share-smoke-${row.id.name}',
            stats: _stats,
          ),
        );

        expect(payload, isNotNull);
        expect(payload!.displayName, row.displayName);
        expect(payload.label, row.label);
        expect(payload.statementTop, row.statementTop);
        expect(payload.statementBottom, row.statementBottom);
        expect(payload.officialExplanation, row.becauseLine);
        expect(payload.motto, row.motto);
        expect(payload.metadata, 'OWNED 26 · COMPLETE 4 · MASTER 1');
        expect(payload.mascotAssetPath, row.asset);
        expect(
          CollectorTypeArchetypes.byId(row.id).accentFor(Brightness.light),
          payload.accent,
        );

        await _pumpCard(tester, CollectorTypeShareCard(payload: payload));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Master Complete title smoke matrix', () {
    final cases = <String>[
      'Molly',
      'Exciting Macaron',
      'MOLLY The Wheel of Time 20th Anniversary Series Figures',
      'A deliberately very long collector series title used to verify wrapping and layout safety',
    ];

    for (final rawName in cases) {
      testWidgets('lays out Chase Card with "$rawName"', (tester) async {
        final payload = MasterCompleteSharePayload(
          label: 'SHELFY CHASE CARD · MASTER',
          seriesName: shareCardSeriesLabel(rawName, uppercase: true),
          image: _assetImage,
          metadata: 'REGULAR 12/12 · SECRET 1/1',
          regularOwned: 12,
          regularTotal: 12,
          secretOwned: 1,
          secretTotal: 1,
        );

        await _pumpCard(tester, MasterCompleteShareCard(payload: payload));

        expect(find.text('THE CHASE'), findsOneWidget);
        expect(find.text('IS COMPLETE'), findsOneWidget);
        expect(find.text('Every Regular.     Every Secret.'), findsOneWidget);
        expect(find.text(payload.seriesName), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    test('shortens normal catalog-style titles before rendering', () {
      expect(
        shareCardSeriesLabel(
          'MOLLY The Wheel of Time 20th Anniversary Series Figures',
          uppercase: true,
        ),
        'MOLLY THE WHEEL OF TIME 20TH ANNIVERSARY',
      );
      expect(
        shareCardSeriesLabel('Exciting Macaron Series', uppercase: true),
        'EXCITING MACARON',
      );
    });
  });

  group('My Shelf collection-size smoke matrix', () {
    for (final count in [0, 1, 2, 3, 6, 9]) {
      testWidgets('lays out Shelf Card with $count featured series', (
        tester,
      ) async {
        final payload = ShelfSharePayload(
          label: 'SHELFY SHELF CARD · CURRENT',
          collectorTypeName: 'The Completionist',
          ownedFigureCount: count * 3,
          trackedSeriesCount: count,
          completedSeriesCount: count >= 3 ? 2 : 0,
          masterCompleteSeriesCount: count >= 6 ? 1 : 0,
          overallRegularProgress: count == 0 ? 0 : 68,
          generatedAt: DateTime.utc(2026),
          featuredSeries: [
            for (var i = 0; i < count.clamp(0, 6); i++)
              ShelfShareSeriesItem(
                seriesId: 'series-$i',
                seriesName: 'Series $i',
                ipName: 'Shelfy',
                image: _assetImage,
                regularProgress: i == 0 ? 1 : 0.68,
                isCompleted: i <= 1,
                isMasterComplete: i == 0,
              ),
          ],
        );

        await _pumpCard(tester, ShelfShareCard(payload: payload));

        expect(find.text('MY SHELF\nRIGHT NOW'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    test('buildShelfSharePayload handles an empty shelf intentionally', () {
      final payload = buildShelfSharePayload(
        snapshot: CollectionSnapshot.emptyTest(),
        generatedAt: DateTime.utc(2026),
      );

      expect(payload.featuredSeries, isEmpty);
      expect(payload.ownedFigureCount, 0);
      expect(payload.trackedSeriesCount, 0);
      expect(payload.overallRegularProgress, 0);
    });
  });

  group('Featured-series selection boundary matrix', () {
    test('is stable for more candidates than available slots', () {
      final snapshot = CollectionSnapshot(
        shelfSeries: [
          _series(id: 'low', name: 'Low', regular: 4),
          _series(id: 'near', name: 'Near', regular: 4),
          _series(id: 'complete-a', name: 'Complete A'),
          _series(id: 'master-a', name: 'Master A'),
          _series(id: 'master-b', name: 'Master B'),
          _series(id: 'tie-a', name: 'Tie A', regular: 4),
          _series(id: 'tie-b', name: 'Tie B', regular: 4),
          _series(id: 'custom', name: 'Custom Local', custom: true),
        ],
        figureStates: {
          ..._owned(['master-a_r0', 'master-a_r1', 'master-a_s0']),
          ..._owned(['master-b_r0', 'master-b_r1', 'master-b_s0']),
          ..._owned(['complete-a_r0', 'complete-a_r1']),
          ..._owned(['near_r0', 'near_r1', 'near_r2']),
          ..._owned(['tie-a_r0', 'tie-a_r1']),
          ..._owned(['tie-b_r0', 'tie-b_r1']),
          ..._owned(['custom_r0']),
          ..._owned(['low_r0']),
        },
      );

      final first = selectShelfShareFeaturedSeries(snapshot);
      final second = selectShelfShareFeaturedSeries(snapshot);

      expect(first.map((s) => s.id), [
        'master-a',
        'master-b',
        'complete-a',
        'near',
        'tie-a',
        'tie-b',
      ]);
      expect(second.map((s) => s.id), first.map((s) => s.id));
      expect(first.map((s) => s.id).toSet(), hasLength(first.length));
    });

    test('uses shelf encounter order when completion and progress tie', () {
      final a = _series(id: 'a', name: 'Zed', regular: 4);
      final b = _series(id: 'b', name: 'Alpha', regular: 4);
      final snapshot = CollectionSnapshot(
        shelfSeries: [a, b],
        figureStates: {
          ..._owned(['a_r0', 'a_r1', 'b_r0', 'b_r1']),
        },
      );

      expect(selectShelfShareFeaturedSeries(snapshot).map((s) => s.id), [
        'a',
        'b',
      ]);
    });
  });

  group('Master Complete payload image/title matrix', () {
    test('requires true Master Complete before building a Chase payload', () {
      final series = _series(id: 'macaron', name: 'Exciting Macaron');

      expect(
        buildMasterCompleteSharePayload(
          series: series,
          figureStates: _owned(['macaron_r0', 'macaron_r1']),
        ),
        isNull,
      );

      final payload = buildMasterCompleteSharePayload(
        series: series,
        figureStates: _owned(['macaron_r0', 'macaron_r1', 'macaron_s0']),
      );

      expect(payload, isNotNull);
      expect(payload!.seriesName, 'EXCITING MACARON');
      expect(payload.metadata, 'REGULAR 2/2 · SECRET 1/1');
      expect(payload.image.kind, ShareCardImageKind.catalogSeries);
    });
  });

  group('PNG renderer output verification', () {
    testWidgets('captures a 360x640 canvas to a 1080x1920 PNG', (tester) async {
      final png = await _captureSimplePng(tester);

      await _expectPngDimensions(png);
    });
  }, skip: 'Requires integration smoke');
}

Future<void> _pumpCard(WidgetTester tester, Widget card) async {
  addTearDown(() => tester.view.resetPhysicalSize());
  addTearDown(() => tester.view.resetDevicePixelRatio());
  tester.view.physicalSize = kShelfyShareCardLogicalSize;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: kShelfyShareCardLogicalSize.width,
            height: kShelfyShareCardLogicalSize.height,
            child: card,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump();
}

Future<Uint8List> _captureSimplePng(WidgetTester tester) async {
  final key = GlobalKey();
  addTearDown(() => tester.view.resetPhysicalSize());
  addTearDown(() => tester.view.resetDevicePixelRatio());
  tester.view.physicalSize = kShelfyShareCardLogicalSize;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ShareCardCaptureBoundary(
            captureKey: key,
            child: const SizedBox(
              width: 360,
              height: 640,
              child: ColoredBox(color: Color(0xFFEDE6F6)),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump();
  return tester
      .runAsync(() => const ShareCardRenderer().capturePng(key))
      .then((bytes) => bytes!);
}

Future<void> _expectPngDimensions(Uint8List bytes) async {
  expect(bytes.length, greaterThan(0));
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  addTearDown(frame.image.dispose);
  expect(frame.image.width, 1080);
  expect(frame.image.height, 1920);
}

ShelfSeries _series({
  required String id,
  required String name,
  int regular = 2,
  int secret = 1,
  bool custom = false,
}) {
  return ShelfSeries(
    id: id,
    name: name,
    brand: 'POP MART',
    ipName: 'Shelfy',
    shelfAccent: Colors.purple,
    catalogTemplateId: custom ? null : id,
    imageKey: id,
    figures: [
      for (var i = 0; i < regular; i++)
        ShelfFigure(
          id: '${id}_r$i',
          seriesId: id,
          name: 'Regular $i',
          rarity: 'Regular',
          isSecret: false,
        ),
      for (var i = 0; i < secret; i++)
        ShelfFigure(
          id: '${id}_s$i',
          seriesId: id,
          name: 'Secret $i',
          rarity: 'Secret',
          isSecret: true,
        ),
    ],
  );
}

Map<String, TrackedFigure> _owned(Iterable<String> ids) {
  return {
    for (final id in ids)
      id: TrackedFigure(figureId: id, state: FigureCollectionState.owned),
  };
}

const _collectorMatrix = [
  _CollectorSmokeRow(
    name: 'Completionist',
    id: CollectorTypeArchetypeId.completionist,
    displayName: 'The Completionist',
    label: 'SHELFY IDENTITY CARD · 03/10',
    statementTop: 'COMPLETED?',
    statementBottom: 'NOT ENOUGH.',
    becauseLine: 'Because completion defines your shelf.',
    motto: 'Every last piece.',
    asset: 'assets/insights/collector_types/completionist.png',
  ),
  _CollectorSmokeRow(
    name: 'Hunter',
    id: CollectorTypeArchetypeId.hunter,
    displayName: 'The Hunter',
    label: 'SHELFY IDENTITY CARD · 02/10',
    statementTop: 'SOME GET LUCKY.',
    statementBottom: 'YOU GO LOOKING.',
    becauseLine: 'Because you actively hunt Secrets\u2014and you catch them.',
    motto: 'Secret by secret.',
    asset: 'assets/insights/collector_types/hunter.png',
  ),
  _CollectorSmokeRow(
    name: 'Lucky One',
    id: CollectorTypeArchetypeId.luckyOne,
    displayName: 'The Lucky One',
    label: 'SHELFY IDENTITY CARD · 10/10',
    statementTop: 'WAS IT LUCK?',
    statementBottom: 'ABSOLUTELY.',
    becauseLine: 'Because luck found you before hunting did.',
    motto: 'Some shelves sparkle early.',
    asset: 'assets/insights/collector_types/lucky_one.png',
  ),
  _CollectorSmokeRow(
    name: 'Loyalist',
    id: CollectorTypeArchetypeId.loyalist,
    displayName: 'The Loyalist',
    label: 'SHELFY IDENTITY CARD · 04/10',
    statementTop: 'ONE WORLD.',
    statementBottom: 'NO REGRETS.',
    becauseLine: 'Because one universe clearly defines your shelf.',
    motto: 'Home shelf, chosen universe.',
    asset: 'assets/insights/collector_types/loyalist.png',
  ),
  _CollectorSmokeRow(
    name: 'Curator',
    id: CollectorTypeArchetypeId.curator,
    displayName: 'The Curator',
    label: 'SHELFY IDENTITY CARD · 05/10',
    statementTop: 'NOT RANDOM.',
    statementBottom: 'CURATED.',
    becauseLine:
        'Because your shelf is a gallery of worlds you genuinely invest in.',
    motto: 'Every world gets its frame.',
    asset: 'assets/insights/collector_types/curator.png',
  ),
  _CollectorSmokeRow(
    name: 'Wanderer',
    id: CollectorTypeArchetypeId.wanderer,
    displayName: 'The Wanderer',
    label: 'SHELFY IDENTITY CARD · 09/10',
    statementTop: 'NO FIXED PATH.',
    statementBottom: 'GOOD FINDS.',
    becauseLine: 'Because your shelf is still discovering what defines it.',
    motto: 'Curiosity leads.',
    asset: 'assets/insights/collector_types/wanderer.png',
  ),
  _CollectorSmokeRow(
    name: 'Minimalist',
    id: CollectorTypeArchetypeId.minimalist,
    displayName: 'The Minimalist',
    label: 'SHELFY IDENTITY CARD · 08/10',
    statementTop: 'LESS SHELF.',
    statementBottom: 'MORE TASTE.',
    becauseLine:
        'Because you keep a small, focused shelf and care deeply for what makes the cut.',
    motto: 'Only what earns the space.',
    asset: 'assets/insights/collector_types/minimalist.png',
  ),
  _CollectorSmokeRow(
    name: 'Worldbuilder',
    id: CollectorTypeArchetypeId.worldbuilder,
    displayName: 'The Worldbuilder',
    label: 'SHELFY IDENTITY CARD · 07/10',
    statementTop: 'DOESN\'T EXIST?',
    statementBottom: 'MAKE IT.',
    becauseLine: 'Because your own creations define your shelf.',
    motto: 'Your shelf has authorship.',
    asset: 'assets/insights/collector_types/worldbuilder.png',
  ),
  _CollectorSmokeRow(
    name: 'Dreamer',
    id: CollectorTypeArchetypeId.dreamer,
    displayName: 'The Dreamer',
    label: 'SHELFY IDENTITY CARD · 01/10',
    statementTop: 'WISHLIST FIRST.',
    statementBottom: 'WALLET LATER.',
    becauseLine:
        'Because you dream about what comes next more than what you already own.',
    motto: 'The shelf starts in your head.',
    asset: 'assets/insights/collector_types/dreamer.png',
  ),
  _CollectorSmokeRow(
    name: 'Trend Chaser',
    id: CollectorTypeArchetypeId.trendChaser,
    displayName: 'The Trend Chaser',
    label: 'SHELFY IDENTITY CARD · 06/10',
    statementTop: 'NEW DROP?',
    statementBottom: 'ALREADY WATCHING.',
    becauseLine: 'Because recent releases define your shelf.',
    motto: 'Fresh finds first.',
    asset: 'assets/insights/collector_types/trend_chaser.png',
  ),
];

class _CollectorSmokeRow {
  const _CollectorSmokeRow({
    required this.name,
    required this.id,
    required this.displayName,
    required this.label,
    required this.statementTop,
    required this.statementBottom,
    required this.becauseLine,
    required this.motto,
    required this.asset,
  });

  final String name;
  final CollectorTypeArchetypeId id;
  final String displayName;
  final String label;
  final String statementTop;
  final String statementBottom;
  final String becauseLine;
  final String motto;
  final String asset;
}
