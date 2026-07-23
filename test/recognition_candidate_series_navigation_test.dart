import 'dart:typed_data';

import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart' as seed;
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart' as seed;
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/open_recognition_candidate_series.dart';
import 'package:blindbox_app/features/collection/widgets/catalog_series_preview_sheet.dart';
import 'package:blindbox_app/features/collection/widgets/series_figures_sheet.dart';
import 'package:blindbox_app/shared/image/catalog_figure_recognition.dart';
import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/catalog_subject_locator_gateway.dart';
import 'package:blindbox_app/shared/image/catalog_subject_selection.dart';
import 'package:blindbox_app/shared/image/whole_image_quality.dart';
import 'package:blindbox_app/shared/widgets/catalog_photo_verification_page.dart';
import 'package:blindbox_app/shared/widgets/collectible_browse_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

CatalogSeedBundle _bundle() {
  return CatalogSeedBundle(
    brands: const [CatalogBrand(id: 'popmart', displayName: 'POP MART')],
    ips: const [
      CatalogIp(id: 'ip_test', brandId: 'popmart', displayName: 'Test IP'),
    ],
    series: const [
      seed.CatalogSeries(
        id: 'series_match',
        brandId: 'popmart',
        ipId: 'ip_test',
        displayName: 'Match Series',
        releaseDate: '2026-01-01',
        isBlindBox: true,
        imageKey: 'series_match',
      ),
    ],
    figures: const [
      seed.CatalogFigure(
        id: 'fig_match',
        seriesId: 'series_match',
        brandId: 'popmart',
        ipId: 'ip_test',
        displayName: 'Matched Figure',
        isSecret: false,
        sortOrder: 0,
        imageKey: 'fig_match',
      ),
      seed.CatalogFigure(
        id: 'fig_other',
        seriesId: 'series_match',
        brandId: 'popmart',
        ipId: 'ip_test',
        displayName: 'Other Figure',
        isSecret: false,
        sortOrder: 1,
        imageKey: 'fig_other',
      ),
    ],
  );
}

final class _MemoryCollectionNotifier extends CollectionNotifier {
  _MemoryCollectionNotifier(this.initial);
  final CollectionSnapshot initial;

  @override
  CollectionSnapshot build() => initial;
}

final class _FakeEvaluator implements WholeImageQualityEvaluator {
  @override
  Future<WholeImageQualityResult> evaluate(
    CatalogPhotoSelection selection,
  ) async {
    return const WholeImageQualityResult(
      outcome: WholeImageQualityOutcome.usable,
      evaluatorVersion: 'test-v1',
    );
  }
}

final class _FakeLocator implements CatalogSubjectLocator {
  @override
  Future<CatalogSubjectLocatorResult> locate(
    CatalogPhotoSelection photo,
  ) async =>
      const CatalogSubjectLocatorNoSuggestion();

  @override
  void cancelPending() {}
}

final class _FakeRecognitionGateway
    implements CatalogFigureRecognitionGateway {
  @override
  Future<CatalogFigureRecognitionResult> recognize(
    CatalogSubjectSelectionResult selection,
  ) async {
    return const CatalogRecognitionCandidates(
      quality: CatalogSubjectQuality.good,
      candidates: [
        CatalogRecognitionCandidate(
          rank: 1,
          figureId: 'fig_match',
          figureName: 'Matched Figure',
          seriesId: 'series_match',
          seriesName: 'Match Series',
          ipId: 'ip_test',
          ipName: 'Test IP',
          imageKey: 'fig_match',
        ),
      ],
    );
  }

  @override
  void cancelPending() {}
}

CatalogPhotoSelection _photo() {
  final preview = image.Image(width: 16, height: 16)
    ..clear(image.ColorRgb8(120, 90, 180));
  return CatalogPhotoSelection(
    file: XFile.fromData(
      Uint8List.fromList(image.encodePng(preview)),
      name: 'photo.png',
      mimeType: 'image/png',
    ),
    source: CatalogPhotoSource.gallery,
  );
}

Future<void> _settlePhoto(WidgetTester tester) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
    if (find
        .byKey(const Key('subject-selection-image'))
        .evaluate()
        .isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 250));
      return;
    }
  }
  fail('Photo did not load');
}

Future<void> _settleFraming(WidgetTester tester) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
    if (find.text('Continue').evaluate().isNotEmpty) {
      await tester.pump(CollectibleMotion.crossfade);
      return;
    }
  }
  fail('Framing did not appear');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CollectionMemoryStore.instance.resetForTest();
    GoogleFonts.config.allowRuntimeFetching = false;
    CatalogBundleCache.prime(_bundle());
  });

  testWidgets(
    'candidate tap opens catalog preview with matched figure, no auto-add',
    (tester) async {
      late WidgetRef ref;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionNotifierProvider.overrideWith(
              () => _MemoryCollectionNotifier(
                const CollectionSnapshot(shelfSeries: [], figureStates: {}),
              ),
            ),
            catalogBundleProvider.overrideWith((ref) async => _bundle()),
          ],
          child: MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
            ),
            home: Scaffold(
              body: Consumer(
                builder: (context, widgetRef, _) {
                  ref = widgetRef;
                  return FilledButton(
                    onPressed: () {
                      showCatalogPhotoVerification(
                        context,
                        _photo(),
                        evaluator: _FakeEvaluator(),
                        locatorGateway: _FakeLocator(),
                        recognitionCoordinator:
                            CatalogFigureRecognitionCoordinator(
                          _FakeRecognitionGateway(),
                        ),
                        onCandidateConfirmed: (candidate) {
                          openRecognitionCandidateSeries(
                            context,
                            ref,
                            seriesId: candidate.seriesId,
                            figureId: candidate.figureId,
                          );
                        },
                      );
                    },
                    child: const Text('Scan'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        ref.read(catalogSeriesTemplateProvider('series_match')),
        isNotNull,
      );

      await tester.tap(find.text('Scan'));
      await _settlePhoto(tester);
      await tester.tap(find.text('Use This Photo'));
      await _settleFraming(tester);
      await tester.tap(find.text('Continue'));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        if (find.text('Close matches').evaluate().isNotEmpty) {
          break;
        }
      }
      expect(find.byKey(const Key('catalog-photo-confirmation')), findsOneWidget);

      final beforeOwned = ref.read(collectionNotifierProvider).shelfSeries.length;
      final candidate = find.byKey(const Key('recognition-candidate-fig_match'));
      tester.widget<CollectibleBrowseCard>(candidate).onTap();
      await tester.pump();
      await tester.pump(CollectibleMotion.sheet);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CatalogSeriesPreviewSheet), findsOneWidget);
      expect(find.text('Match Series'), findsWidgets);
      expect(find.text('Matched Figure'), findsWidgets);
      expect(
        find.byKey(const Key('recognition-matched-figure-label')),
        findsOneWidget,
      );
      expect(find.text('Matched from your photo'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(ref.read(collectionNotifierProvider).shelfSeries.length, beforeOwned);
      expect(find.byKey(const Key('catalog-photo-confirmation')), findsOneWidget);

      // Pop the stacked Series preview; scan results remain underneath.
      Navigator.of(
        tester.element(find.byKey(const Key('catalog-photo-confirmation'))),
      ).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CatalogSeriesPreviewSheet), findsNothing);
      expect(find.text('Close matches'), findsOneWidget);
      expect(find.text('Create Custom Figure'), findsOneWidget);

      await tester.tap(find.byKey(const Key('catalog-photo-close')));
      await tester.pump();
      await tester.pump(CollectibleMotion.sheetDismiss);
    },
  );

  testWidgets(
    'candidate tap opens SeriesFiguresSheet when series already on shelf',
    (tester) async {
      final shelf = testShelfSeries(
        id: 'series_match',
        name: 'Match Series',
        catalogTemplateId: 'series_match',
        figures: const [
          ShelfFigure(
            id: 'fig_match',
            seriesId: 'series_match',
            name: 'Matched Figure',
            rarity: 'Regular',
            isSecret: false,
            catalogFigureTemplateId: 'fig_match',
          ),
          ShelfFigure(
            id: 'fig_other',
            seriesId: 'series_match',
            name: 'Other Figure',
            rarity: 'Regular',
            isSecret: false,
            catalogFigureTemplateId: 'fig_other',
          ),
        ],
      );
      late WidgetRef ref;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionNotifierProvider.overrideWith(
              () => _MemoryCollectionNotifier(
                CollectionSnapshot(
                  shelfSeries: [shelf],
                  figureStates: {
                    'fig_match': const TrackedFigure(
                      figureId: 'fig_match',
                      state: FigureCollectionState.none,
                    ),
                  },
                ),
              ),
            ),
            catalogBundleProvider.overrideWith((ref) async => _bundle()),
          ],
          child: MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
            ),
            home: Scaffold(
              body: Consumer(
                builder: (context, widgetRef, _) {
                  ref = widgetRef;
                  return FilledButton(
                    onPressed: () {
                      openRecognitionCandidateSeries(
                        context,
                        ref,
                        seriesId: 'series_match',
                        figureId: 'fig_match',
                      );
                    },
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(CollectibleMotion.sheet);

      expect(find.byType(SeriesFiguresSheet), findsOneWidget);
      expect(
        find.byKey(const Key('recognition-matched-figure-label')),
        findsOneWidget,
      );
      expect(
        ref.read(collectionNotifierProvider).figureStates['fig_match']?.state,
        FigureCollectionState.none,
      );

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(CollectibleMotion.sheetDismiss);
    },
  );
}
