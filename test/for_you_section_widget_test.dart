import 'dart:async';

import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as catalog;
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/recommendations/application/anonymous_id_provider.dart';
import 'package:blindbox_app/features/recommendations/application/recommendations_provider.dart';
import 'package:blindbox_app/features/recommendations/application/recommendation_readiness_provider.dart';
import 'package:blindbox_app/features/recommendations/data/preference_signal_extractor.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_item.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_reason_type.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_result.dart';
import 'package:blindbox_app/features/recommendations/presentation/for_you_copy.dart';
import 'package:blindbox_app/features/recommendations/widgets/for_you_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/collection_fixtures.dart';

CatalogSeedBundle _testBundle() {
  return CatalogSeedBundle(
    brands: const [CatalogBrand(id: 'popmart', displayName: 'POP MART')],
    ips: const [
      CatalogIp(id: 'dimoo', brandId: 'popmart', displayName: 'DIMOO'),
    ],
    series: const [
      catalog.CatalogSeries(
        id: 'dimoo_new',
        brandId: 'popmart',
        ipId: 'dimoo',
        displayName: 'Dimoo New',
        releaseDate: '2026-05-01',
        isBlindBox: true,
        imageKey: 'dimoo_new',
      ),
    ],
    figures: const [],
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await resetRecommendationReadinessPrefsForTest();
    CollectionAppBootstrap.prime(
      CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(
            id: 'owned',
            catalogTemplateId: 'dimoo_owned',
            taxonomyIpId: 'dimoo',
            figures: [
              const ShelfFigure(
                id: 'owned_fig',
                seriesId: 'owned',
                name: 'Owned',
                rarity: 'Regular',
                isSecret: false,
                catalogFigureTemplateId: 'fig_owned',
              ),
            ],
          ),
        ],
        figureStates: const {
          'owned_fig': TrackedFigure(
            figureId: 'owned_fig',
            state: FigureCollectionState.owned,
          ),
        },
      ),
    );
  });

  group('resolveForYouDisplayResult', () {
    RecommendationResult resultWithItems() {
      return RecommendationResult(
        items: [
          RecommendationItem(
            seriesId: 'dimoo_new',
            reasonType: RecommendationReasonType.ownedIp,
            reasonMeta: 'DIMOO',
            series: _testBundle().series.first,
          ),
        ],
      );
    }

    test('returns previous result while loading after first paint', () {
      final previous = resultWithItems();
      expect(
        resolveForYouDisplayResult(
          recommendationsAsync: const AsyncLoading(),
          previousResult: previous,
        ),
        previous,
      );
    });

    test('returns null while loading when no previous result exists', () {
      expect(
        resolveForYouDisplayResult(
          recommendationsAsync: const AsyncLoading(),
          previousResult: null,
        ),
        isNull,
      );
    });

    test('prefers latest data over previous result', () {
      final previous = resultWithItems();
      final latest = RecommendationResult(items: const []);
      expect(
        resolveForYouDisplayResult(
          recommendationsAsync: AsyncData(latest),
          previousResult: previous,
        ),
        latest,
      );
    });

    test('keeps previous result on refresh error when available', () {
      final previous = resultWithItems();
      expect(
        resolveForYouDisplayResult(
          recommendationsAsync: AsyncError(
            Exception('offline'),
            StackTrace.empty,
          ),
          previousResult: previous,
        ),
        previous,
      );
    });

    test('returns null on first-load error when no previous result exists', () {
      expect(
        resolveForYouDisplayResult(
          recommendationsAsync: AsyncError(
            Exception('offline'),
            StackTrace.empty,
          ),
          previousResult: null,
        ),
        isNull,
      );
    });

    test('visibleForYouResult drops tracked series from stale keep-previous rail', () {
      final previous = resultWithItems();
      final signals = PreferenceSignals(
        trackedCatalogSeriesIds: {'dimoo_new'},
        ownedCatalogSeriesIds: const {},
        wishlistCatalogSeriesIds: const {},
        ownedIpIds: const {},
        wishlistIpIds: const {},
        trackedCatalogSeriesCount: 1,
        ownedCatalogSeriesCount: 0,
        wishlistCatalogSeriesCount: 0,
        profileHash: 'hash',
      );

      expect(
        visibleForYouResult(displayResult: previous, signals: signals)?.items,
        isEmpty,
      );
    });
  });

  testWidgets('ForYouSection hidden when readiness is false', (tester) async {
    CollectionAppBootstrap.prime(CollectionSnapshot.emptyTest());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recommendationReadinessProvider.overrideWith(
            () => _HiddenReadinessNotifier(),
          ),
          catalogBundleProvider.overrideWith((ref) async => _testBundle()),
          recommendationsProvider.overrideWith(
            (ref) async => RecommendationResult(
              items: [
                RecommendationItem(
                  seriesId: 'dimoo_new',
                  reasonType: RecommendationReasonType.ownedIp,
                  reasonMeta: 'DIMOO',
                  series: _testBundle().series.first,
                ),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ForYouSection()),
        ),
      ),
    );

    await tester.pump();
    expect(find.text(ForYouCopy.sectionTitle), findsNothing);
  });

  testWidgets('ForYouSection reserves no vertical space when hidden', (tester) async {
    CollectionAppBootstrap.prime(CollectionSnapshot.emptyTest());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recommendationReadinessProvider.overrideWith(
            () => _HiddenReadinessNotifier(),
          ),
          catalogBundleProvider.overrideWith((ref) async => _testBundle()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ForYouSection()),
        ),
      ),
    );

    await tester.pump();

    final box = tester.renderObject<RenderBox>(find.byType(ForYouSection));
    expect(box.size.height, 0);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.height == FeedRhythm.homeMajorSectionGap,
      ),
      findsNothing,
    );
  });

  testWidgets('ForYouSection includes major gap below when visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recommendationReadinessProvider.overrideWith(
            () => _ReadyReadinessNotifier(),
          ),
          catalogBundleProvider.overrideWith((ref) async => _testBundle()),
          anonymousInstallIdProvider.overrideWith((ref) async => 'test-install'),
          recommendationsProvider.overrideWith(
            (ref) async => RecommendationResult(
              items: [
                RecommendationItem(
                  seriesId: 'dimoo_new',
                  reasonType: RecommendationReasonType.ownedIp,
                  reasonMeta: 'DIMOO',
                  series: _testBundle().series.first,
                ),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ForYouSection()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.height == FeedRhythm.homeMajorSectionGap,
      ),
      findsOneWidget,
    );
    expect(
      tester.renderObject<RenderBox>(find.byType(ForYouSection)).size.height,
      greaterThan(FeedRhythm.homeMajorSectionGap),
    );
  });

  testWidgets('ForYouSection shows skeleton on first load', (tester) async {
    final completer = Completer<RecommendationResult>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recommendationReadinessProvider.overrideWith(
            () => _ReadyReadinessNotifier(),
          ),
          catalogBundleProvider.overrideWith((ref) async => _testBundle()),
          anonymousInstallIdProvider.overrideWith((ref) async => 'test-install'),
          recommendationsProvider.overrideWith((ref) => completer.future),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ForYouSection()),
        ),
      ),
    );

    await tester.pump();

    expect(find.text(ForYouCopy.sectionTitle), findsOneWidget);
    expect(find.text('Dimoo New'), findsNothing);

    completer.complete(const RecommendationResult(items: []));
    await tester.pumpAndSettle();
  });

  testWidgets('ForYouSection hidden when recommendations fail', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recommendationReadinessProvider.overrideWith(
            () => _ReadyReadinessNotifier(),
          ),
          catalogBundleProvider.overrideWith((ref) async => _testBundle()),
          anonymousInstallIdProvider.overrideWith((ref) async => 'test-install'),
          recommendationsProvider.overrideWith(
            (ref) async => throw Exception('offline'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ForYouSection()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text(ForYouCopy.sectionTitle), findsNothing);
  });

  testWidgets('ForYouSection hidden while catalog bundle is unavailable',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recommendationReadinessProvider.overrideWith(
            () => _ReadyReadinessNotifier(),
          ),
          catalogBundleProvider.overrideWith(
            (ref) async => throw Exception('catalog offline'),
          ),
          recommendationsProvider.overrideWith(
            (ref) async => RecommendationResult(
              items: [
                RecommendationItem(
                  seriesId: 'dimoo_new',
                  reasonType: RecommendationReasonType.ownedIp,
                  reasonMeta: 'DIMOO',
                  series: _testBundle().series.first,
                ),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ForYouSection()),
        ),
      ),
    );

    await tester.pump();

    expect(find.text(ForYouCopy.sectionTitle), findsNothing);
  });

  testWidgets('ForYouSection shows reason line when ready and data present',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recommendationReadinessProvider.overrideWith(
            () => _ReadyReadinessNotifier(),
          ),
          catalogBundleProvider.overrideWith((ref) async => _testBundle()),
          anonymousInstallIdProvider.overrideWith((ref) async => 'test-install'),
          recommendationsProvider.overrideWith(
            (ref) async => RecommendationResult(
              items: [
                RecommendationItem(
                  seriesId: 'dimoo_new',
                  reasonType: RecommendationReasonType.ownedIp,
                  reasonMeta: 'DIMOO',
                  series: _testBundle().series.first,
                ),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(child: ForYouSection()),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text(ForYouCopy.sectionTitle), findsOneWidget);
    expect(find.text('Because you collect DIMOO'), findsOneWidget);
    expect(find.text('Dimoo New'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
  });

  testWidgets('ForYou title icon stays visible after horizontal scroll', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recommendationReadinessProvider.overrideWith(
            () => _ReadyReadinessNotifier(),
          ),
          catalogBundleProvider.overrideWith((ref) async => _testBundle()),
          anonymousInstallIdProvider.overrideWith((ref) async => 'test-install'),
          recommendationsProvider.overrideWith(
            (ref) async => RecommendationResult(
              items: List.generate(
                6,
                (index) => RecommendationItem(
                  seriesId: 'dimoo_new',
                  reasonType: RecommendationReasonType.ownedIp,
                  reasonMeta: 'DIMOO',
                  series: _testBundle().series.first,
                ),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(child: ForYouSection()),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(-240, 0));
    await tester.pump();

    expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
  });
}

class _ReadyReadinessNotifier extends RecommendationReadinessNotifier {
  @override
  bool build() => true;
}

class _HiddenReadinessNotifier extends RecommendationReadinessNotifier {
  @override
  bool build() => false;
}
