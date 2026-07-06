import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as catalog;
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/recommendations/application/anonymous_id_provider.dart';
import 'package:blindbox_app/features/recommendations/application/recommendations_provider.dart';
import 'package:blindbox_app/features/recommendations/application/recommendation_readiness_provider.dart';
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
              fetchedAt: DateTime.now(),
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
              fetchedAt: DateTime.now(),
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
              fetchedAt: DateTime.now(),
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
