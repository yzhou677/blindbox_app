import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_management.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

final class _ManageTestNotifier extends CollectionNotifier {
  _ManageTestNotifier(this._snap);
  CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;

  @override
  void removeSeries(String seriesId) {
    super.removeSeries(seriesId);
    _snap = state;
  }
}

ShelfSeries _customSeries() {
  const seriesId = 'custom_manage_test';
  return ShelfSeries(
    id: seriesId,
    name: 'Handmade Set',
    brand: 'DPL',
    ipName: 'Baby Three',
    taxonomyBrandId: 'dpl',
    taxonomyIpId: 'baby_three',
    catalogTemplateId: null,
    imageKey: seriesId,
    figures: const [
      ShelfFigure(
        id: 'custom_manage_test-f-0',
        seriesId: seriesId,
        name: 'One',
        rarity: 'Regular',
        isSecret: false,
      ),
    ],
    shelfAccent: Color(0xFFE4F2EA),
  );
}

void main() {
  testWidgets('custom series action sheet includes Edit and Remove', (
    tester,
  ) async {
    final series = _customSeries();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _ManageTestNotifier(
              CollectionSnapshot(shelfSeries: [series], figureStates: const {}),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showCollectionSeriesManagementActions(
                  context: context,
                  ref: ref,
                  series: series,
                ),
                child: const Text('manage'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('manage'));
    await tester.pumpAndSettle();

    expect(find.text(CollectionVocabulary.editSeries), findsOneWidget);
    expect(find.text(CollectionVocabulary.removeFromCollection), findsOneWidget);
    expect(find.text(CollectionVocabulary.cancel), findsOneWidget);
  });

  testWidgets('catalog series action sheet omits Edit', (tester) async {
    final series = testShelfSeries(name: 'Catalog Set');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _ManageTestNotifier(
              CollectionSnapshot(shelfSeries: [series], figureStates: const {}),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showCollectionSeriesManagementActions(
                  context: context,
                  ref: ref,
                  series: series,
                ),
                child: const Text('manage'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('manage'));
    await tester.pumpAndSettle();

    expect(find.text(CollectionVocabulary.editSeries), findsNothing);
    expect(find.text(CollectionVocabulary.removeFromCollection), findsOneWidget);
  });

  testWidgets('long-press on card invokes management callback', (tester) async {
    final series = testShelfSeries();
    var managed = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CollectionSeriesCard(
            series: series,
            progress: progressForSeries(series, const {}),
            figureStates: const {},
            onTap: () {},
            onLongPress: () async {
              managed += 1;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final inkWell = find.descendant(
      of: find.byType(CollectionSeriesCard),
      matching: find.byType(InkWell),
    );
    final gesture = await tester.startGesture(tester.getCenter(inkWell));
    await tester.pump(kLongPressTimeout);
    await tester.pump(); // start _handleLongPress after recognition
    await tester.pump(const Duration(milliseconds: 120)); // press hold
    await gesture.up();
    await tester.pump();

    expect(managed, 1);
  });
}
