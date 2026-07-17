import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/features/home/widgets/save_series_release_button.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SeededCollectionNotifier extends CollectionNotifier {
  _SeededCollectionNotifier(this._snapshot);
  final CollectionSnapshot _snapshot;

  @override
  CollectionSnapshot build() => _snapshot;
}

SeriesRelease _release({
  required String dropId,
  required String seriesName,
  required String brand,
  String? taxonomyBrandId,
  String? taxonomyIpId,
}) {
  return SeriesRelease(
    dropId: dropId,
    seriesName: seriesName,
    brand: brand,
    releaseDate: DateTime(2026, 1, 1),
    seriesImageKey: 'series_key',
    taxonomyBrandId: taxonomyBrandId,
    taxonomyIpId: taxonomyIpId,
    heroCollectible: Collectible(
      id: dropId,
      name: 'Hero',
      series: seriesName,
      brand: brand,
      releaseDate: DateTime(2026, 1, 1),
      imageUrl: '',
    ),
    lineup: const [
      ReleaseLineupSlot(
        slotId: 'slot_1',
        name: 'A',
        imageKey: 'img_a',
        isSecret: false,
      ),
    ],
  );
}

ShelfSeries _shelf({
  required String id,
  required String name,
  required String brand,
  String? catalogTemplateId,
  String? taxonomyBrandId,
  String? taxonomyIpId,
}) {
  return ShelfSeries(
    id: id,
    name: name,
    brand: brand,
    ipName: 'IP',
    figures: const [
      ShelfFigure(
        id: 'f1',
        seriesId: 's1',
        name: 'Figure',
        rarity: 'Regular',
        isSecret: false,
      ),
    ],
    shelfAccent: const Color(0xFFE8DEF5),
    catalogTemplateId: catalogTemplateId,
    taxonomyBrandId: taxonomyBrandId,
    taxonomyIpId: taxonomyIpId,
  );
}

Future<void> _pumpButton(
  WidgetTester tester, {
  required CollectionSnapshot snapshot,
  required SeriesRelease release,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionNotifierProvider.overrideWith(
          () => _SeededCollectionNotifier(snapshot),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SaveSeriesReleaseButton(
              release: release,
              variant: SeriesReleaseShelfCtaVariant.filled,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('discovery CTA shows owned state for exact catalog template match', (
    tester,
  ) async {
    const dropId = 'hirono_drop';
    final snapshot = CollectionSnapshot(
      shelfSeries: [
        _shelf(
          id: 's1',
          name: 'The Other One',
          brand: 'POP MART',
          catalogTemplateId: 'drop-$dropId',
        ),
      ],
      figureStates: const {},
    );
    await _pumpButton(
      tester,
      snapshot: snapshot,
      release: _release(
        dropId: dropId,
        seriesName: 'The Other One',
        brand: 'POP MART',
      ),
    );
    expect(find.text('In your collection'), findsOneWidget);
    expect(find.text('Add to my collection'), findsNothing);
  });

  testWidgets('discovery CTA shows owned state for canonical custom match', (
    tester,
  ) async {
    final snapshot = CollectionSnapshot(
      shelfSeries: [
        _shelf(
          id: 'custom_1',
          name: 'Crybaby - Ocean',
          brand: 'POP MART',
          catalogTemplateId: null,
        ),
      ],
      figureStates: const {},
    );
    await _pumpButton(
      tester,
      snapshot: snapshot,
      release: _release(
        dropId: 'crybaby_ocean_drop',
        seriesName: 'Crybaby_Ocean',
        brand: 'popmart',
      ),
    );
    expect(find.text('In your collection'), findsOneWidget);
    expect(find.text('Add to my collection'), findsNothing);
  });

  testWidgets('discovery CTA remains add when custom entry is unmatched', (
    tester,
  ) async {
    final snapshot = CollectionSnapshot(
      shelfSeries: [
        _shelf(
          id: 'custom_1',
          name: 'Spring Picnic customs',
          brand: 'Local Artist',
          catalogTemplateId: null,
        ),
      ],
      figureStates: const {},
    );
    await _pumpButton(
      tester,
      snapshot: snapshot,
      release: _release(
        dropId: 'hirono_drop',
        seriesName: 'The Other One',
        brand: 'POP MART',
      ),
    );
    expect(find.text('Add to my collection'), findsOneWidget);
    expect(find.text('In your collection'), findsNothing);
  });

  testWidgets('discovery CTA reactively updates after collection write', (
    tester,
  ) async {
    final container = ProviderContainer();

    final release = _release(
      dropId: 'where_moments_meet',
      seriesName: 'Where Moments Meet Series Plush Doll',
      brand: 'Nyota',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SaveSeriesReleaseButton(
                release: release,
                variant: SeriesReleaseShelfCtaVariant.filled,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add to my collection'), findsOneWidget);

    final template = CatalogSeries(
      templateId: 'where_moments_meet',
      name: 'Where Moments Meet',
      brand: 'Nyota',
      ipName: 'Nyota',
      figures: const [
        CatalogFigure(
          templateFigureId: 'wm-1',
          catalogSeriesTemplateId: 'where_moments_meet',
          name: 'Where Moments Meet Plush Doll',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
      shelfAccent: const Color(0xFFE8DEF5),
    );
    container.read(collectionNotifierProvider.notifier).addSeriesFromTemplate(
      template,
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('In your collection'), findsOneWidget);
    expect(find.text('Add to my collection'), findsNothing);

    container.dispose();
  });

  testWidgets('release wishlist heart adds with snackbar undo', (tester) async {
    final release = _release(
      dropId: 'wish_drop',
      seriesName: 'Wish Drop',
      brand: 'POP MART',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _SeededCollectionNotifier(CollectionSnapshot.emptyTest()),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: SeriesReleaseWishlistButton(release: release)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();

    expect(find.text('Added to Wishlist'), findsOneWidget);
    expect(find.text('UNDO'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    await tester.tap(find.text('UNDO'));
    await tester.pump();

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
  });
}
