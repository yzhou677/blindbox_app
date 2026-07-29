import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as catalog;
import 'package:blindbox_app/features/catalog/presentation/us_release_date_copy.dart';
import 'package:blindbox_app/features/catalog/presentation/us_release_date_line.dart';
import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_providers.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/collection_series_identity.dart';
import 'package:blindbox_app/features/collection/data/series_release_lookup.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_shelf_cta_presentation.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:blindbox_app/features/collection/widgets/catalog_series_preview_sheet.dart';
import 'package:blindbox_app/features/collection/widgets/series_figures_sheet.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/features/home/drop_detail_screen.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/collection_fixtures.dart';

SeriesRelease _release({
  required DateTime releaseDate,
  String dropId = 'series_a',
}) {
  return SeriesRelease(
    dropId: dropId,
    seriesName: 'Exciting Macaron',
    brand: 'POP MART',
    ipLine: 'POP MART · THE MONSTERS',
    releaseDate: releaseDate,
    seriesImageKey: 'series_key',
    heroCollectible: Collectible(
      id: dropId,
      name: 'Hero',
      series: 'Exciting Macaron',
      brand: 'POP MART',
      releaseDate: releaseDate,
      imageUrl: '',
    ),
    lineup: const [
      ReleaseLineupSlot(
        slotId: 'f1',
        name: 'Figure 1',
        imageKey: 'fig_1',
        isSecret: false,
      ),
    ],
  );
}

final class _ReleaseDateSheetNotifier extends CollectionNotifier {
  _ReleaseDateSheetNotifier(this._snap);
  final CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;
}

CatalogSeedBundle _bundleWithRelease({
  required String seriesId,
  required String? releaseDate,
}) {
  return CatalogSeedBundle(
    brands: const [],
    ips: const [],
    series: [
      catalog.CatalogSeries(
        id: seriesId,
        brandId: 'pop_mart',
        ipId: 'the_monsters',
        displayName: 'Test Series',
        releaseDate: releaseDate,
        isBlindBox: true,
        imageKey: seriesId,
      ),
    ],
    figures: const [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('formatUsReleaseDateLine', () {
    testWidgets('formats a valid U.S. release date with U.S. label', (
      tester,
    ) async {
      late MaterialLocalizations locs;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en', 'US'),
          home: Builder(
            builder: (context) {
              locs = MaterialLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final line = formatUsReleaseDateLine(DateTime(2025, 5, 23), locs);
      expect(line, isNotNull);
      expect(line, contains(UsReleaseDateCopy.label));
      expect(line, contains('U.S.'));
      expect(line, contains('2025'));
      expect(line, contains('23'));
    });

    test('missing and malformed catalog strings do not parse', () {
      expect(parseCatalogReleaseDate(null), isNull);
      expect(parseCatalogReleaseDate(''), isNull);
      expect(parseCatalogReleaseDate('   '), isNull);
      expect(parseCatalogReleaseDate('not-a-date'), isNull);
      expect(parseCatalogReleaseDate('2025-05-23'), DateTime(2025, 5, 23));
    });
  });

  group('UsReleaseDateLine', () {
    testWidgets('shows U.S. label, date, and accessible info control', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en', 'US'),
          home: Scaffold(
            body: UsReleaseDateLine(releaseDate: DateTime(2025, 5, 23)),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('us_release_date_line')), findsOneWidget);
      expect(find.textContaining('U.S. Release Date'), findsOneWidget);
      expect(find.textContaining('2025'), findsOneWidget);

      final info = find.byKey(const Key('us_release_date_info'));
      expect(info, findsOneWidget);
      expect(
        tester.getSemantics(info),
        matchesSemantics(
          label: UsReleaseDateCopy.infoSemanticLabel,
          isButton: true,
          hasTapAction: true,
          tooltip: UsReleaseDateCopy.disclosure,
        ),
      );

      await tester.tap(info);
      await tester.pump();
      expect(find.text(UsReleaseDateCopy.disclosure), findsOneWidget);
    });

    testWidgets('hides the complete row when release date is missing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: UsReleaseDateLine(releaseDate: null)),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('us_release_date_line')), findsNothing);
      expect(find.textContaining('U.S. Release Date'), findsNothing);
      expect(find.textContaining('Unknown'), findsNothing);
      expect(find.textContaining('N/A'), findsNothing);
    });
  });

  group('DropDetailScreen', () {
    testWidgets('shows U.S. release date in Series Detail meta', (
      tester,
    ) async {
      final release = _release(releaseDate: DateTime(2025, 5, 23));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            seriesReleaseLookupProvider.overrideWith(
              (ref) =>
                  (id) => release,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('en', 'US'),
            home: DropDetailScreen(releaseId: release.dropId),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Exciting Macaron'), findsWidgets);

      // Hero art pushes meta below the default 600px test viewport.
      final releaseLine = find.byKey(
        const Key('us_release_date_line'),
        skipOffstage: false,
      );
      expect(releaseLine, findsOneWidget);
      await tester.ensureVisible(releaseLine);
      await tester.pump();

      expect(find.textContaining('U.S. Release Date'), findsOneWidget);
      expect(find.textContaining('2025'), findsOneWidget);
    });

    testWidgets('malformed lookup does not crash the screen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            seriesReleaseLookupProvider.overrideWith(
              (ref) =>
                  (id) => null,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const DropDetailScreen(releaseId: 'missing'),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('could not be found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('SeriesFiguresSheet', () {
    testWidgets('shows U.S. release date from catalog join', (tester) async {
      final shelf = testShelfSeries(
        id: 'shelf_1',
        catalogTemplateId: 'catalog_series_test',
      );
      final snap = CollectionSnapshot(
        shelfSeries: [shelf],
        figureStates: const {},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionNotifierProvider.overrideWith(
              () => _ReleaseDateSheetNotifier(snap),
            ),
            catalogBundleProvider.overrideWith(
              (ref) async => _bundleWithRelease(
                seriesId: 'catalog_series_test',
                releaseDate: '2025-05-23',
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: CollectibleSheetScope(
                scrollController: ScrollController(),
                child: const SeriesFiguresSheet(seriesId: 'shelf_1'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('us_release_date_line')), findsOneWidget);
      expect(find.textContaining('U.S. Release Date'), findsOneWidget);
      expect(find.byKey(const Key('us_release_date_info')), findsOneWidget);
    });

    testWidgets('hides release date when catalog has none', (tester) async {
      final shelf = testShelfSeries(
        id: 'shelf_1',
        catalogTemplateId: 'catalog_series_test',
      );
      final snap = CollectionSnapshot(
        shelfSeries: [shelf],
        figureStates: const {},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionNotifierProvider.overrideWith(
              () => _ReleaseDateSheetNotifier(snap),
            ),
            catalogBundleProvider.overrideWith(
              (ref) async => _bundleWithRelease(
                seriesId: 'catalog_series_test',
                releaseDate: null,
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: CollectibleSheetScope(
                scrollController: ScrollController(),
                child: const SeriesFiguresSheet(seriesId: 'shelf_1'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('U.S. Release Date'), findsNothing);
    });
  });

  group('CatalogSeriesPreviewSheet', () {
    testWidgets('shows U.S. release date from catalog lookup', (tester) async {
      final template = testCatalogTemplate();
      final cta = CollectionSeriesShelfCtaPresentation.fromOwnership(
        const CollectionSeriesOwnershipMatch.notOwned(),
        layout: CollectionSeriesShelfCtaLayout.previewSticky,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            relationshipHintForCatalogSeriesProvider.overrideWith(
              (ref, _) => null,
            ),
            catalogBundleProvider.overrideWith(
              (ref) async => _bundleWithRelease(
                seriesId: template.templateId,
                releaseDate: '2025-05-23',
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: CollectibleSheetScope(
                scrollController: ScrollController(),
                child: CatalogSeriesPreviewSheet(
                  series: template,
                  shelfCta: cta,
                  onAdd: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('us_release_date_line')), findsOneWidget);
      expect(find.textContaining('U.S. Release Date'), findsOneWidget);
    });
  });

  test('Recently Released semantic label clarifies U.S. scope', () {
    expect(
      CollectionShelfSort.recentlyReleased.semanticLabel,
      contains('U.S.'),
    );
    expect(CollectionShelfSort.recentlyReleased.menuLabel, 'Recently Released');
  });
}
