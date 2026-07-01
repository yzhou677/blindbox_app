import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/core/theme/collectible_tokens.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/presentation/collection_summary_editorial.dart';
import 'package:blindbox_app/features/collection/widgets/collection_insights_dashboard.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

const _goldenDir = 'goldens/collection_insights_dashboard';

/// Offline-stable theme (no Google Fonts network fetch).
ThemeData _auditTheme({double textScale = 1.0}) {
  const seed = Color(0xFFA892CC);
  final raw = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
  final scheme = raw.copyWith(
    primary: const Color(0xFF6652A5),
    onPrimary: const Color(0xFFFFFBFE),
    primaryContainer: const Color(0xFFE4D6F8),
    onPrimaryContainer: const Color(0xFF2A1F3D),
    secondary: const Color(0xFFE59878),
    tertiary: const Color(0xFFB49AE0),
    tertiaryContainer: const Color(0xFFF0E9FA),
    surface: const Color(0xFFFFFAFC),
    surfaceContainerLow: const Color(0xFFF5F0FA),
    surfaceContainer: const Color(0xFFEBE4F3),
    surfaceContainerHigh: const Color(0xFFE0D7EE),
    outlineVariant: const Color(0xFFC8B8D8),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Color.lerp(
      scheme.surfaceContainerLow,
      scheme.surface,
      0.42,
    ),
    extensions: <ThemeExtension<dynamic>>[
      CollectibleTokens.forBrightness(Brightness.light),
    ],
  );
}

const _auditLogicalSizes = <(double w, double h)>[
  (320, 568),
  (360, 640),
  (393, 852),
  (412, 915),
  (600, 960),
  (800, 1280),
];

const _auditTextScales = <double>[1.0, 1.15, 1.3, 1.5];

const _emptyStats = CollectionAggregateStats(
  inCollection: 0,
  wantListCount: 0,
  completedSeriesCount: 0,
  masterCompleteSeriesCount: 0,
);

const _typicalStats = CollectionAggregateStats(
  inCollection: 48,
  wantListCount: 3,
  completedSeriesCount: 7,
  masterCompleteSeriesCount: 5,
);

const _largeStats = CollectionAggregateStats(
  inCollection: 9999,
  wantListCount: 128,
  completedSeriesCount: 999,
  masterCompleteSeriesCount: 256,
);

const _longMoodLine =
    'Your collection is quietly taking shape across many shelves, seasons, '
    'and small rituals of discovery that never really end.';
const _longWhisper =
    'A gentle milestone on the shelf — each figure a memory, each series a '
    'chapter you return to when the day finally slows down.';
const _longCollectorType =
    'Archivist of Midnight Market Finds and Rare Chase Variants';

@immutable
class _DashboardScenario {
  const _DashboardScenario({
    required this.name,
    required this.stats,
    this.shelfMoodLine,
    this.memoryWhisper,
    this.collectorTypeName,
    this.onInsightsTap,
    this.expand = false,
  });

  final String name;
  final CollectionAggregateStats stats;
  final String? shelfMoodLine;
  final String? memoryWhisper;
  final String? collectorTypeName;
  final VoidCallback? onInsightsTap;
  final bool expand;
}

final _scenarios = <_DashboardScenario>[
  const _DashboardScenario(name: 'collapsed', stats: _typicalStats),
  _DashboardScenario(
    name: 'expand',
    stats: _typicalStats,
    shelfMoodLine: 'Your collection is quietly taking shape.',
    memoryWhisper: 'A gentle milestone on the shelf.',
    collectorTypeName: 'Curator',
    onInsightsTap: _noop,
    expand: true,
  ),
  _DashboardScenario(
    name: 'empty_collection',
    stats: _emptyStats,
    expand: true,
    onInsightsTap: _noop,
  ),
  _DashboardScenario(
    name: 'large_collection',
    stats: _largeStats,
    expand: true,
    onInsightsTap: _noop,
  ),
  const _DashboardScenario(
    name: 'cta_absent',
    stats: _typicalStats,
    expand: true,
  ),
  _DashboardScenario(
    name: 'cta_present',
    stats: _typicalStats,
    shelfMoodLine: 'Quiet momentum.',
    collectorTypeName: 'Curator',
    onInsightsTap: _noop,
    expand: true,
  ),
  _DashboardScenario(
    name: 'long_shelfMoodLine',
    stats: _typicalStats,
    shelfMoodLine: _longMoodLine,
    onInsightsTap: _noop,
    expand: true,
  ),
  _DashboardScenario(
    name: 'long_memoryWhisper',
    stats: _typicalStats,
    memoryWhisper: _longWhisper,
    onInsightsTap: _noop,
    expand: true,
  ),
  _DashboardScenario(
    name: 'long_collectorTypeName',
    stats: _typicalStats,
    collectorTypeName: _longCollectorType,
    onInsightsTap: _noop,
    expand: true,
  ),
  _DashboardScenario(
    name: 'maximum_editorial',
    stats: _typicalStats,
    shelfMoodLine: _longMoodLine,
    memoryWhisper: _longWhisper,
    collectorTypeName: _longCollectorType,
    onInsightsTap: _noop,
    expand: true,
  ),
];

void _noop() {}

void _configureSurface(
  WidgetTester tester, {
  required double width,
  required double height,
  double textScale = 1.0,
}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Widget _dashboardColumn({
  required _DashboardScenario scenario,
  Key? dashboardKey,
}) {
  return MaterialApp(
    theme: _auditTheme(),
    home: Scaffold(
      body: CustomScrollView(
        key: const Key('collection_audit_scroll'),
        cacheExtent: 10000,
        slivers: [
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: dashboardKey ?? const Key('collection_insights_dashboard_slot'),
              child: CollectionInsightsDashboard(
                stats: scenario.stats,
                shelfMoodLine: scenario.shelfMoodLine,
                memoryWhisper: scenario.memoryWhisper,
                collectorTypeName: scenario.collectorTypeName,
                onInsightsTap: scenario.onInsightsTap,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Text(
              'My collection',
              key: const Key('my_collection_header'),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _pumpScenario(
  WidgetTester tester,
  _DashboardScenario scenario, {
  required double width,
  required double height,
  double textScale = 1.0,
}) async {
  _configureSurface(tester, width: width, height: height, textScale: textScale);
  await tester.pumpWidget(_dashboardColumn(scenario: scenario));
  await tester.pumpAndSettle();
  if (scenario.expand) {
    await tester.tap(find.byKey(const Key('collection_insights_dashboard_toggle')));
    await tester.pump();
    await tester.pump(CollectibleMotion.insightsDashboardTransition);
    await tester.pumpAndSettle();
  }
}

void _expectNoLayoutExceptions(WidgetTester tester) {
  expect(tester.takeException(), isNull, reason: 'RenderFlex overflow or layout error');
}

void _expectHeaderBelowDashboard(WidgetTester tester) {
  final position = PrimaryScrollController.of(
    tester.element(find.byKey(const Key('collection_audit_scroll'))),
  ).position;
  final slotRect = tester.getRect(
    find.byKey(const Key('collection_insights_dashboard_slot')),
  );

  expect(
    position.maxScrollExtent + position.viewportDimension,
    greaterThan(slotRect.bottom + 1),
    reason: 'scroll extent must reserve space for content below dashboard',
  );

  if (find.byKey(const Key('my_collection_header')).evaluate().isNotEmpty) {
    final headerRect = tester.getRect(
      find.byKey(const Key('my_collection_header')),
    );
    expect(
      headerRect.top,
      greaterThanOrEqualTo(slotRect.bottom - 1),
      reason: 'My collection must not overlap dashboard extent',
    );
  }
}

void _expectFinderContainedInSlot(WidgetTester tester, Finder content) {
  expect(content, findsOneWidget);
  final slotRect = tester.getRect(
    find.byKey(const Key('collection_insights_dashboard_slot')),
  );
  final contentRect = tester.getRect(content);
  expect(
    slotRect.top,
    lessThanOrEqualTo(contentRect.top + 1),
    reason: '$content top clipped above dashboard slot',
  );
  expect(
    slotRect.bottom,
    greaterThanOrEqualTo(contentRect.bottom - 1),
    reason: '$content bottom clipped inside dashboard slot',
  );
}

void _expectNoExcessiveGapBelowContent(
  WidgetTester tester,
  Finder lastContent, {
  double maxGap = 28,
}) {
  final slotRect = tester.getRect(
    find.byKey(const Key('collection_insights_dashboard_slot')),
  );
  final contentRect = tester.getRect(lastContent);
  expect(
    slotRect.bottom - contentRect.bottom,
    lessThanOrEqualTo(maxGap),
    reason: 'dashboard slot taller than intrinsic content (blank gap)',
  );
}

Future<void> _toggleExpandCollapse(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('collection_insights_dashboard_toggle')));
  await tester.pump();
  await tester.pump(CollectibleMotion.insightsDashboardTransition);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('measure scheduling coalescing (logic mirror)', () {
    test('only one post-frame registration per frame batch', () {
      var measureScheduled = false;
      var callbackRegistrations = 0;

      void scheduleMeasure({required bool needsMeasure}) {
        if (!needsMeasure) return;
        if (measureScheduled) return;
        measureScheduled = true;
        callbackRegistrations++;
      }

      void commitMeasure() {
        measureScheduled = false;
      }

      scheduleMeasure(needsMeasure: true);
      scheduleMeasure(needsMeasure: true);
      scheduleMeasure(needsMeasure: true);
      expect(callbackRegistrations, 1);

      commitMeasure();
      scheduleMeasure(needsMeasure: true);
      expect(callbackRegistrations, 2);
    });
  });

  group('multi-device layout matrix', () {
    for (final size in _auditLogicalSizes) {
      for (final textScale in _auditTextScales) {
        for (final scenario in _scenarios) {
          testWidgets(
            '${size.$1}x${size.$2} @${textScale}x ${scenario.name}',
            (tester) async {
              await _pumpScenario(
                tester,
                scenario,
                width: size.$1,
                height: size.$2,
                textScale: textScale,
              );
              _expectNoLayoutExceptions(tester);
              expect(
                find.byKey(const Key('collection_insights_dashboard_slot')),
                findsOneWidget,
                reason: 'dashboard slot must remain mounted',
              );
              _expectHeaderBelowDashboard(tester);

              if (scenario.expand) {
                _expectFinderContainedInSlot(
                  tester,
                  find.text(CollectionSummaryLabels.figures),
                );
                if (scenario.shelfMoodLine != null) {
                  _expectFinderContainedInSlot(
                    tester,
                    find.text(scenario.shelfMoodLine!),
                  );
                }
                if (scenario.memoryWhisper != null) {
                  _expectFinderContainedInSlot(
                    tester,
                    find.text(scenario.memoryWhisper!),
                  );
                }
                if (scenario.collectorTypeName != null &&
                    scenario.onInsightsTap != null) {
                  _expectFinderContainedInSlot(
                    tester,
                    find.text(
                      '${CollectorTypeCopy.entryRevealedPrefix}: ${scenario.collectorTypeName}',
                    ),
                  );
                } else if (scenario.onInsightsTap != null) {
                  _expectFinderContainedInSlot(
                    tester,
                    find.text(CollectorTypeCopy.entryCta),
                  );
                }
              } else {
                _expectFinderContainedInSlot(
                  tester,
                  find.byKey(const Key('collection_insights_compact_glance')),
                );
              }
            },
          );
        }
      }
    }
  });

  group('async provider growth + expand', () {
    testWidgets('remeasures after burst input growth before expand', (
      tester,
    ) async {
      _configureSurface(tester, width: 393, height: 852);
      await tester.pumpWidget(
        _dashboardColumn(
          scenario: const _DashboardScenario(name: 'minimal', stats: _typicalStats),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _dashboardColumn(
          scenario: _DashboardScenario(
            name: 'burst',
            stats: _typicalStats,
            shelfMoodLine: _longMoodLine,
            memoryWhisper: _longWhisper,
            collectorTypeName: _longCollectorType,
            onInsightsTap: _noop,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await _toggleExpandCollapse(tester);

      _expectNoLayoutExceptions(tester);
      _expectHeaderBelowDashboard(tester);
      _expectFinderContainedInSlot(tester, find.text(_longMoodLine));
      _expectFinderContainedInSlot(
        tester,
        find.text(
          '${CollectorTypeCopy.entryRevealedPrefix}: $_longCollectorType',
        ),
      );
    });
  });

  group('measurement invalidation paths', () {
    testWidgets('stats change remeasures collapsed and expanded', (
      tester,
    ) async {
      _configureSurface(tester, width: 393, height: 852);
      const initial = _typicalStats;
      const updated = CollectionAggregateStats(
        inCollection: 120,
        wantListCount: 8,
        completedSeriesCount: 22,
        masterCompleteSeriesCount: 11,
      );

      await tester.pumpWidget(
        _dashboardColumn(
          scenario: _DashboardScenario(
            name: 'stats',
            stats: initial,
            onInsightsTap: _noop,
            expand: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _toggleExpandCollapse(tester);
      final expandedBefore = tester.getSize(
        find.byKey(const Key('collection_insights_dashboard_slot')),
      ).height;

      await tester.pumpWidget(
        _dashboardColumn(
          scenario: _DashboardScenario(
            name: 'stats_updated',
            stats: updated,
            onInsightsTap: _noop,
            expand: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      _expectNoLayoutExceptions(tester);
      expect(find.text('120'), findsWidgets);
      final expandedAfter = tester.getSize(
        find.byKey(const Key('collection_insights_dashboard_slot')),
      ).height;
      expect(expandedAfter, greaterThanOrEqualTo(expandedBefore - 1));
      _expectHeaderBelowDashboard(tester);
    });

    testWidgets('CTA visibility change remeasures expanded height', (
      tester,
    ) async {
      _configureSurface(tester, width: 393, height: 852);

      await tester.pumpWidget(
        _dashboardColumn(
          scenario: const _DashboardScenario(
            name: 'no_cta',
            stats: _typicalStats,
            expand: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _toggleExpandCollapse(tester);
      final withoutCta = tester.getSize(
        find.byKey(const Key('collection_insights_dashboard_slot')),
      ).height;

      await tester.pumpWidget(
        _dashboardColumn(
          scenario: _DashboardScenario(
            name: 'with_cta',
            stats: _typicalStats,
            onInsightsTap: _noop,
            expand: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      final withCta = tester.getSize(
        find.byKey(const Key('collection_insights_dashboard_slot')),
      ).height;
      expect(withCta, greaterThan(withoutCta));
      _expectFinderContainedInSlot(tester, find.text(CollectorTypeCopy.entryCta));
      _expectHeaderBelowDashboard(tester);
    });
  });

  group('post-frame coalescing integration', () {
    testWidgets('single-frame burst invalidation schedules one measure pass', (
      tester,
    ) async {
      _configureSurface(tester, width: 393, height: 852);
      var postFrameCallbacks = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: _auditTheme(),
          home: Scaffold(
            body: _BurstInputsHarness(
              onBuild: () {
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  postFrameCallbacks++;
                });
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final harness = tester.state<_BurstInputsHarnessState>(
        find.byType(_BurstInputsHarness),
      );
      postFrameCallbacks = 0;
      harness.burstUpdate();
      await tester.pump();
      await tester.pump();

      expect(
        postFrameCallbacks,
        1,
        reason: 'one frame should run one post-frame callback batch tail',
      );

      await harness.expandDashboard(tester);
      _expectNoLayoutExceptions(tester);
      _expectHeaderBelowDashboard(tester);
      _expectFinderContainedInSlot(tester, find.text(_longMoodLine));
    });
  });

  group('stress — 20 expand/collapse cycles', () {
    testWidgets('no layout drift or overflow', (tester) async {
      _configureSurface(tester, width: 393, height: 852);
      final scenario = _DashboardScenario(
        name: 'stress',
        stats: _typicalStats,
        shelfMoodLine: _longMoodLine,
        memoryWhisper: _longWhisper,
        collectorTypeName: 'Curator',
        onInsightsTap: _noop,
      );

      await tester.pumpWidget(_dashboardColumn(scenario: scenario));
      await tester.pumpAndSettle();

      final collapsedHeights = <double>[];
      final expandedHeights = <double>[];

      for (var i = 0; i < 20; i++) {
        await _toggleExpandCollapse(tester);
        expandedHeights.add(
          tester
              .getSize(find.byKey(const Key('collection_insights_dashboard_slot')))
              .height,
        );
        _expectNoLayoutExceptions(tester);
        _expectHeaderBelowDashboard(tester);

        await _toggleExpandCollapse(tester);
        collapsedHeights.add(
          tester
              .getSize(find.byKey(const Key('collection_insights_dashboard_slot')))
              .height,
        );
        _expectNoLayoutExceptions(tester);
      }

      expect(collapsedHeights.first, closeTo(collapsedHeights.last, 2));
      expect(expandedHeights.first, closeTo(expandedHeights.last, 2));
    });
  });

  group('golden snapshots', () {
    Future<void> pumpGolden(
      WidgetTester tester, {
      required String name,
      required double width,
      required double height,
      required _DashboardScenario scenario,
    }) async {
      _configureSurface(tester, width: width, height: height);
      await tester.pumpWidget(
        MaterialApp(
          theme: _auditTheme(),
          home: Scaffold(
            body: Center(
              child: KeyedSubtree(
                key: const Key('collection_insights_dashboard_golden'),
                child: CollectionInsightsDashboard(
                  stats: scenario.stats,
                  shelfMoodLine: scenario.shelfMoodLine,
                  memoryWhisper: scenario.memoryWhisper,
                  collectorTypeName: scenario.collectorTypeName,
                  onInsightsTap: scenario.onInsightsTap,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (scenario.expand) {
        await tester.tap(
          find.byKey(const Key('collection_insights_dashboard_toggle')),
        );
        await tester.pump();
        await tester.pump(CollectibleMotion.insightsDashboardTransition);
        await tester.pumpAndSettle();
      }

      await expectLater(
        find.byKey(const Key('collection_insights_dashboard_golden')),
        matchesGoldenFile('$_goldenDir/$name.png'),
      );
    }

    const goldenScenarios = <({String file, _DashboardScenario scenario})>[
      (
        file: 'collapsed_393',
        scenario: _DashboardScenario(name: 'collapsed', stats: _typicalStats),
      ),
      (
        file: 'expanded_393',
        scenario: _DashboardScenario(
          name: 'expanded',
          stats: _typicalStats,
          shelfMoodLine: 'Your collection is quietly taking shape.',
          memoryWhisper: 'A gentle milestone on the shelf.',
          collectorTypeName: 'Curator',
          onInsightsTap: _noop,
          expand: true,
        ),
      ),
      (
        file: 'empty_collection_393',
        scenario: _DashboardScenario(
          name: 'empty',
          stats: _emptyStats,
          onInsightsTap: _noop,
          expand: true,
        ),
      ),
      (
        file: 'populated_collection_393',
        scenario: _DashboardScenario(
          name: 'populated',
          stats: _typicalStats,
          onInsightsTap: _noop,
          expand: true,
        ),
      ),
      (
        file: 'maximum_editorial_393',
        scenario: _DashboardScenario(
          name: 'max_editorial',
          stats: _typicalStats,
          shelfMoodLine: _longMoodLine,
          memoryWhisper: _longWhisper,
          collectorTypeName: _longCollectorType,
          onInsightsTap: _noop,
          expand: true,
        ),
      ),
      (
        file: 'long_collector_type_393',
        scenario: _DashboardScenario(
          name: 'long_collector',
          stats: _typicalStats,
          collectorTypeName: _longCollectorType,
          onInsightsTap: _noop,
          expand: true,
        ),
      ),
      (
        file: 'long_shelf_mood_393',
        scenario: _DashboardScenario(
          name: 'long_mood',
          stats: _typicalStats,
          shelfMoodLine: _longMoodLine,
          onInsightsTap: _noop,
          expand: true,
        ),
      ),
      (
        file: 'long_memory_whisper_393',
        scenario: _DashboardScenario(
          name: 'long_whisper',
          stats: _typicalStats,
          memoryWhisper: _longWhisper,
          onInsightsTap: _noop,
          expand: true,
        ),
      ),
      (
        file: 'cta_present_393',
        scenario: _DashboardScenario(
          name: 'cta_present',
          stats: _typicalStats,
          collectorTypeName: 'Curator',
          onInsightsTap: _noop,
          expand: true,
        ),
      ),
      (
        file: 'cta_absent_393',
        scenario: _DashboardScenario(
          name: 'cta_absent',
          stats: _typicalStats,
          expand: true,
        ),
      ),
      (
        file: 'collapsed_320',
        scenario: const _DashboardScenario(name: 'collapsed', stats: _typicalStats),
      ),
      (
        file: 'expanded_320',
        scenario: _DashboardScenario(
          name: 'expanded',
          stats: _typicalStats,
          shelfMoodLine: 'Your collection is quietly taking shape.',
          onInsightsTap: _noop,
          expand: true,
        ),
      ),
      (
        file: 'collapsed_600',
        scenario: const _DashboardScenario(name: 'collapsed', stats: _typicalStats),
      ),
      (
        file: 'expanded_600',
        scenario: _DashboardScenario(
          name: 'expanded',
          stats: _typicalStats,
          shelfMoodLine: 'Your collection is quietly taking shape.',
          onInsightsTap: _noop,
          expand: true,
        ),
      ),
    ];

    for (final entry in goldenScenarios) {
      final width = entry.file.contains('_320')
          ? 320.0
          : entry.file.contains('_600')
          ? 600.0
          : 393.0;
      final height = entry.file.contains('_320')
          ? 568.0
          : entry.file.contains('_600')
          ? 960.0
          : 852.0;

      testWidgets('golden ${entry.file}', (tester) async {
        await pumpGolden(
          tester,
          name: entry.file,
          width: width,
          height: height,
          scenario: entry.scenario,
        );
      });
    }
  });
}

class _BurstInputsHarness extends StatefulWidget {
  const _BurstInputsHarness({required this.onBuild});

  final VoidCallback onBuild;

  @override
  State<_BurstInputsHarness> createState() => _BurstInputsHarnessState();
}

class _BurstInputsHarnessState extends State<_BurstInputsHarness> {
  CollectionAggregateStats _stats = _typicalStats;
  String? _mood;
  String? _whisper;
  String? _collector;
  VoidCallback? _cta;

  void burstUpdate() {
    setState(() {
      _stats = _largeStats;
      _mood = _longMoodLine;
      _whisper = _longWhisper;
      _collector = _longCollectorType;
      _cta = _noop;
    });
  }

  Future<void> expandDashboard(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('collection_insights_dashboard_toggle')));
    await tester.pump();
    await tester.pump(CollectibleMotion.insightsDashboardTransition);
    await tester.pumpAndSettle();
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return CustomScrollView(
      key: const Key('collection_audit_scroll'),
      cacheExtent: 10000,
      slivers: [
        SliverToBoxAdapter(
          child: KeyedSubtree(
            key: const Key('collection_insights_dashboard_slot'),
            child: CollectionInsightsDashboard(
              stats: _stats,
              shelfMoodLine: _mood,
              memoryWhisper: _whisper,
              collectorTypeName: _collector,
              onInsightsTap: _cta,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Text(
            'My collection',
            key: const Key('my_collection_header'),
          ),
        ),
      ],
    );
  }
}
