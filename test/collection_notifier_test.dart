import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_journey_summary.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_ip_facets.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_storage.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'helpers/collection_fixtures.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer newContainer() {
    CollectionAppBootstrap.prime(
      CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(
            figures: [
              const ShelfFigure(
                id: 'fig_cycle',
                seriesId: 'series_test',
                name: 'Cycle Me',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
        ],
        figureStates: const {},
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(collectionNotifierProvider);
    return container;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CollectionMemoryStore.instance.resetForTest();
  });

  /// Empty shelf container without auto-dispose — for memory flush scenarios.
  ProviderContainer newEmptyMemoryContainer() {
    CollectionAppBootstrap.prime(CollectionSnapshot.emptyTest());
    final container = ProviderContainer();
    container.read(collectionNotifierProvider);
    return container;
  }

  test('cycleFigure advances none → wishlist → owned → clears', () {
    final container = newContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.cycleFigure('fig_cycle');
    expect(
      container.read(collectionNotifierProvider).trackedOrDefault('fig_cycle').state,
      FigureCollectionState.wishlist,
    );

    n.cycleFigure('fig_cycle');
    expect(
      container.read(collectionNotifierProvider).trackedOrDefault('fig_cycle').state,
      FigureCollectionState.owned,
    );

    n.cycleFigure('fig_cycle');
    expect(
      container.read(collectionNotifierProvider).figureStates.containsKey('fig_cycle'),
      isFalse,
    );
  });

  test('cycleFigure ignores unknown figure id', () {
    final container = newContainer();
    final n = container.read(collectionNotifierProvider.notifier);
    n.cycleFigure('not_on_shelf');
    expect(container.read(collectionNotifierProvider).figureStates, isEmpty);
  });

  test('addSeriesFromRelease stores imageKey without imageUrl', () {
    CollectionAppBootstrap.prime(CollectionSnapshot.emptyTest());
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(collectionNotifierProvider.notifier);

    const imageKey = 'the_monsters_exciting_macaron_soymilk';
    final release = SeriesRelease(
      dropId: 'the_monsters_exciting_macaron',
      seriesName: 'Exciting Macaron',
      brand: 'POP MART',
      ipLine: 'POP MART · The Monsters',
      releaseDate: DateTime(2026, 3, 1),
      seriesImageKey: 'the_monsters_exciting_macaron',
      heroCollectible: Collectible(
        id: 'the_monsters_exciting_macaron',
        name: 'Soymilk',
        series: 'Exciting Macaron',
        brand: 'POP MART',
        releaseDate: DateTime(2026, 3, 1),
        imageUrl: '',
        shelfAccent: const Color(0xFFE8F5E9),
      ),
      lineup: const [
        ReleaseLineupSlot(
          slotId: imageKey,
          name: 'Soymilk',
          imageKey: imageKey,
          isSecret: false,
        ),
      ],
      taxonomyBrandId: 'pop_mart',
      taxonomyIpId: 'the_monsters',
    );

    n.addSeriesFromRelease(release);
    final shelf = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(shelf.catalogTemplateId, 'drop-the_monsters_exciting_macaron');
    final fig = shelf.figures.single;
    expect(fig.imageKey, imageKey);
    expect(fig.imageUrl, isNull);
  });

  test('addSeriesFromRelease dedupes when drop template already on shelf', () {
    CollectionAppBootstrap.prime(CollectionSnapshot.emptyTest());
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(collectionNotifierProvider.notifier);

    final release = SeriesRelease(
      dropId: 'dedupe_drop',
      seriesName: 'Dedupe Series',
      brand: 'POP MART',
      releaseDate: DateTime(2026, 3, 1),
      seriesImageKey: 'dedupe_drop',
      heroCollectible: Collectible(
        id: 'dedupe_drop',
        name: 'Hero',
        series: 'Dedupe Series',
        brand: 'POP MART',
        releaseDate: DateTime(2026, 3, 1),
        imageUrl: '',
      ),
      lineup: const [
        ReleaseLineupSlot(
          slotId: 'slot_a',
          name: 'A',
          imageKey: 'the_monsters_exciting_macaron_soymilk',
          isSecret: false,
        ),
      ],
    );

    n.addSeriesFromRelease(release);
    n.addSeriesFromRelease(release);

    final snap = container.read(collectionNotifierProvider);
    expect(
      snap.shelfSeries.where((s) => s.catalogTemplateId == 'drop-dedupe_drop'),
      hasLength(1),
    );
  });

  test('addSeriesFromRelease leaves imageUrl null when imageKey is empty', () async {
    CollectionAppBootstrap.prime(CollectionSnapshot.emptyTest());
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(collectionNotifierProvider.notifier);

    final release = SeriesRelease(
      dropId: 'no_key_drop',
      seriesName: 'No Key',
      brand: 'POP MART',
      releaseDate: DateTime(2026, 3, 1),
      seriesImageKey: 'no_key_drop',
      heroCollectible: Collectible(
        id: 'no_key_drop',
        name: 'Hero',
        series: 'No Key',
        brand: 'POP MART',
        releaseDate: DateTime(2026, 3, 1),
        imageUrl: '',
      ),
      lineup: const [
        ReleaseLineupSlot(
          slotId: 'slot_x',
          name: 'X',
          imageKey: '',
          isSecret: false,
        ),
      ],
    );

    n.addSeriesFromRelease(release);
    final fig = container.read(collectionNotifierProvider).shelfSeries.single.figures.single;
    expect(fig.imageKey, isNull);
    expect(fig.imageUrl, isNull);
  });

  test('addSeriesFromTemplate prepends clone and dedupes by templateId', () {
    final container = newContainer();
    final n = container.read(collectionNotifierProvider.notifier);
    final template = testCatalogTemplate(templateId: 'new_series_tpl');

    n.addSeriesFromTemplate(template);
    n.addSeriesFromTemplate(template);

    final snap = container.read(collectionNotifierProvider);
    expect(snap.shelfSeries.where((s) => s.catalogTemplateId == 'new_series_tpl'), hasLength(1));
    expect(snap.shelfSeries.first.catalogTemplateId, 'new_series_tpl');
    expect(snap.shelfSeries.first.figures.first.rarity, '1:144');
  });

  test('removeSeries drops figures from figureStates', () {
    CollectionAppBootstrap.prime(
      CollectionSnapshot(
        shelfSeries: [testShelfSeries()],
        figureStates: {
          'fig_test_0': const TrackedFigure(
            figureId: 'fig_test_0',
            state: FigureCollectionState.owned,
          ),
        },
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(collectionNotifierProvider);

    container.read(collectionNotifierProvider.notifier).removeSeries('series_test');
    final snap = container.read(collectionNotifierProvider);
    expect(snap.shelfSeries, isEmpty);
    expect(snap.figureStates, isEmpty);
  });

  test('removeSeriesByCatalogTemplate removes shelf row and figure states', () {
    CollectionAppBootstrap.prime(
      CollectionSnapshot(
        shelfSeries: [
          testShelfSeries(catalogTemplateId: 'drop-release-1'),
        ],
        figureStates: {
          'fig_test_0': const TrackedFigure(
            figureId: 'fig_test_0',
            state: FigureCollectionState.wishlist,
          ),
        },
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(collectionNotifierProvider);

    container
        .read(collectionNotifierProvider.notifier)
        .removeSeriesByCatalogTemplate('drop-release-1');
    final snap = container.read(collectionNotifierProvider);
    expect(snap.shelfSeries, isEmpty);
    expect(snap.figureStates, isEmpty);
  });

  test('addCustomSeries truncates over-length metadata at save time', () {
    CollectionAppBootstrap.prime(CollectionSnapshot.emptyTest());
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(collectionNotifierProvider.notifier);

    n.addCustomSeries(
      seriesName: 'S' * 120,
      brand: 'B' * 60,
      ipDisplayName: 'I' * 90,
      notes: 'N' * 600,
      figures: [
        CustomFigureDraft(
          displayName: 'F' * 90,
          isSecret: true,
          rarityLabel: '1' * 30,
        ),
      ],
    );

    final added = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(added.name.length, 80);
    expect(added.brand.length, lessThanOrEqualTo(48));
    expect(added.ipName.length, lessThanOrEqualTo(64));
    expect(added.notes!.length, 500);
    final fig = added.figures.single;
    expect(fig.name.length, 64);
    expect(fig.rarityLabel!.length, 16);
  });

  test('addCustomSeries canonicalizes after sanitizing messy brand and IP', () {
    CollectionAppBootstrap.prime(CollectionSnapshot.emptyTest());
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(collectionNotifierProvider.notifier);

    n.addCustomSeries(
      seriesName: 'My Baby Three Set',
      brand: '  dpl  ',
      ipDisplayName: ' babythree\n',
      figures: const [
        CustomFigureDraft(displayName: 'Fig 1'),
        CustomFigureDraft(displayName: 'Fig 2'),
      ],
    );

    final added = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(added.brand, 'Cureplaneta');
    expect(added.taxonomyBrandId, 'dpl');
    expect(added.ipName, 'Baby Three');
    expect(added.taxonomyIpId, 'baby_three');
  });

  test('addCustomSeries canonicalizes known brand and IP at save time', () {
    CollectionAppBootstrap.prime(CollectionSnapshot.emptyTest());
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(collectionNotifierProvider.notifier);

    n.addCustomSeries(
      seriesName: 'My Baby Three Set',
      brand: 'dpl',
      ipDisplayName: 'babythree',
      figures: const [
        CustomFigureDraft(displayName: 'Fig 1'),
        CustomFigureDraft(displayName: 'Fig 2'),
      ],
    );

    final added = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(added.brand, 'Cureplaneta');
    expect(added.taxonomyBrandId, 'dpl');
    expect(added.ipName, 'Baby Three');
    expect(added.taxonomyIpId, 'baby_three');

    for (final fig in added.figures) {
      expect(fig.taxonomyBrandId, 'dpl');
      expect(fig.taxonomyIpId, 'baby_three');
    }
  });

  test('addCustomSeries keeps unmatched custom brand and IP unchanged', () {
    CollectionAppBootstrap.prime(CollectionSnapshot.emptyTest());
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(collectionNotifierProvider.notifier);

    n.addCustomSeries(
      seriesName: 'Fan Art',
      brand: 'POP',
      ipDisplayName: 'Custom Labubu Fan Art',
      figures: const [CustomFigureDraft(displayName: 'One')],
    );

    final added = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(added.brand, 'POP');
    expect(added.taxonomyBrandId, 'pop');
    expect(added.ipName, 'Custom Labubu Fan Art');
    expect(added.taxonomyIpId, 'custom_labubu_fan_art');
  });

  test('addCustomSeries skips empty figure names', () {
    CollectionAppBootstrap.prime(CollectionSnapshot.emptyTest());
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(collectionNotifierProvider.notifier);

    n.addCustomSeries(
      seriesName: 'My Set',
      figures: const [
        CustomFigureDraft(displayName: '  '),
      ],
    );
    expect(container.read(collectionNotifierProvider).shelfSeries, isEmpty);

    n.addCustomSeries(
      seriesName: 'My Set',
      figures: const [
        CustomFigureDraft(
          displayName: 'Alpha',
          isSecret: true,
          rarityLabel: '1:72',
        ),
      ],
    );
    final added = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(added.isCustomLocal, isTrue);
    expect(added.taxonomyBrandId, 'independent');
    expect(added.imageKey, added.id);
    final fig = added.figures.single;
    expect(fig.name, 'Alpha');
    expect(fig.isSecret, isTrue);
    expect(fig.rarityLabel, '1:72');
    expect(fig.imageKey, '${added.id}-f-0');
    expect(fig.rarity, '1:72');
  });

  // ---------------------------------------------------------------------------
  // updateCustomSeries
  // ---------------------------------------------------------------------------

  ShelfSeries editableCustomSeries() {
    const seriesId = 'custom_edit_1';
    return ShelfSeries(
      id: seriesId,
      name: 'My Baby Three Set',
      brand: 'DPL',
      ipName: 'Baby Three',
      taxonomyBrandId: 'dpl',
      taxonomyIpId: 'baby_three',
      catalogTemplateId: null,
      imageKey: seriesId,
      notes: 'Original note',
      figures: const [
        ShelfFigure(
          id: 'custom_edit_1-f-0',
          seriesId: seriesId,
          name: 'Fig A',
          rarity: 'Regular',
          isSecret: false,
          imageKey: 'custom_edit_1-f-0',
          taxonomyBrandId: 'dpl',
          taxonomyIpId: 'baby_three',
        ),
        ShelfFigure(
          id: 'custom_edit_1-f-1',
          seriesId: seriesId,
          name: 'Fig B',
          rarity: '1:72',
          isSecret: true,
          rarityLabel: '1:72',
          imageKey: 'custom_edit_1-f-1',
          taxonomyBrandId: 'dpl',
          taxonomyIpId: 'baby_three',
        ),
      ],
      shelfAccent: Color(0xFFE4F2EA),
    );
  }

  ProviderContainer newEditableCustomContainer() {
    final series = editableCustomSeries();
    CollectionAppBootstrap.prime(
      CollectionSnapshot(
        shelfSeries: [series],
        figureStates: const {
          'custom_edit_1-f-0': TrackedFigure(
            figureId: 'custom_edit_1-f-0',
            state: FigureCollectionState.owned,
          ),
          'custom_edit_1-f-1': TrackedFigure(
            figureId: 'custom_edit_1-f-1',
            state: FigureCollectionState.wishlist,
          ),
        },
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(collectionNotifierProvider);
    return container;
  }

  test('updateCustomSeries truncates over-length metadata at save time', () {
    final container = newEditableCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.updateCustomSeries(
      seriesId: 'custom_edit_1',
      seriesName: 'R' * 120,
      brand: 'B' * 60,
      ipDisplayName: 'I' * 90,
      notes: 'E' * 700,
    );

    final updated = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(updated.name.length, 80);
    expect(updated.brand.length, lessThanOrEqualTo(48));
    expect(updated.ipName.length, lessThanOrEqualTo(64));
    expect(updated.notes!.length, 500);
    expect(updated.figures.length, 2);
    expect(
      container.read(collectionNotifierProvider).trackedOrDefault('custom_edit_1-f-0').state,
      FigureCollectionState.owned,
    );
  });

  test('updateCustomSeries edits brand only and syncs figure taxonomy', () {
    final container = newEditableCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.updateCustomSeries(
      seriesId: 'custom_edit_1',
      seriesName: 'My Baby Three Set',
      brand: 'POP MART',
      ipDisplayName: 'Baby Three',
    );

    final updated = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(updated.id, 'custom_edit_1');
    expect(updated.brand, 'POP MART');
    expect(updated.taxonomyBrandId, 'pop_mart');
    expect(updated.ipName, 'Baby Three');
    expect(updated.taxonomyIpId, 'baby_three');

    for (final fig in updated.figures) {
      expect(fig.taxonomyBrandId, 'pop_mart');
      expect(fig.taxonomyIpId, 'baby_three');
    }
  });

  test('updateCustomSeries edits IP only and syncs figure taxonomy', () {
    final container = newEditableCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.updateCustomSeries(
      seriesId: 'custom_edit_1',
      seriesName: 'My Baby Three Set',
      brand: 'DPL',
      ipDisplayName: 'the monsters',
    );

    final updated = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(updated.brand, 'Cureplaneta');
    expect(updated.taxonomyBrandId, 'dpl');
    expect(updated.ipName, 'THE MONSTERS');
    expect(updated.taxonomyIpId, 'the_monsters');

    for (final fig in updated.figures) {
      expect(fig.taxonomyBrandId, 'dpl');
      expect(fig.taxonomyIpId, 'the_monsters');
    }
  });

  test('updateCustomSeries edits brand and IP together', () {
    final container = newEditableCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.updateCustomSeries(
      seriesId: 'custom_edit_1',
      seriesName: 'Renamed Set',
      brand: 'dpl',
      ipDisplayName: 'babythree',
    );

    final updated = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(updated.name, 'Renamed Set');
    expect(updated.brand, 'Cureplaneta');
    expect(updated.taxonomyBrandId, 'dpl');
    expect(updated.ipName, 'Baby Three');
    expect(updated.taxonomyIpId, 'baby_three');
  });

  test('updateCustomSeries keeps unknown custom brand and IP unchanged', () {
    final container = newEditableCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.updateCustomSeries(
      seriesId: 'custom_edit_1',
      seriesName: 'My Baby Three Set',
      brand: 'POP',
      ipDisplayName: 'Custom Labubu Fan Art',
    );

    final updated = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(updated.brand, 'POP');
    expect(updated.taxonomyBrandId, 'pop');
    expect(updated.ipName, 'Custom Labubu Fan Art');
    expect(updated.taxonomyIpId, 'custom_labubu_fan_art');
  });

  test('updateCustomSeries preserves figure ids and collection states', () {
    final container = newEditableCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.updateCustomSeries(
      seriesId: 'custom_edit_1',
      seriesName: 'My Baby Three Set',
      brand: 'POP MART',
      ipDisplayName: 'THE MONSTERS',
      notes: 'Updated note',
    );

    final snap = container.read(collectionNotifierProvider);
    final updated = snap.shelfSeries.single;
    expect(updated.figures.map((f) => f.id), ['custom_edit_1-f-0', 'custom_edit_1-f-1']);
    expect(updated.figures[0].name, 'Fig A');
    expect(updated.figures[1].name, 'Fig B');
    expect(updated.figures[1].isSecret, isTrue);
    expect(updated.figures[1].rarityLabel, '1:72');
    expect(updated.figures[0].imageKey, 'custom_edit_1-f-0');
    expect(updated.notes, 'Updated note');
    expect(updated.imageKey, 'custom_edit_1');

    expect(
      snap.trackedOrDefault('custom_edit_1-f-0').state,
      FigureCollectionState.owned,
    );
    expect(
      snap.trackedOrDefault('custom_edit_1-f-1').state,
      FigureCollectionState.wishlist,
    );
  });

  test('updateCustomSeries ignores catalog-backed series', () {
    CollectionAppBootstrap.prime(
      CollectionSnapshot(
        shelfSeries: [testShelfSeries()],
        figureStates: const {},
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(collectionNotifierProvider.notifier);

    n.updateCustomSeries(
      seriesId: 'series_test',
      seriesName: 'Hacked',
      brand: 'DPL',
      ipDisplayName: 'Baby Three',
    );

    final unchanged = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(unchanged.name, 'Test Series');
    expect(unchanged.brand, 'POP MART');
  });

  // ---------------------------------------------------------------------------
  // updateCustomFigure
  // ---------------------------------------------------------------------------

  test('updateCustomFigure updates name and keeps figure id', () {
    final container = newEditableCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.updateCustomFigure(
      seriesId: 'custom_edit_1',
      figureId: 'custom_edit_1-f-0',
      name: 'Renamed Fig A',
      isSecret: false,
    );

    final fig = container.read(collectionNotifierProvider).shelfSeries.single.figures[0];
    expect(fig.id, 'custom_edit_1-f-0');
    expect(fig.name, 'Renamed Fig A');
  });

  test('updateCustomFigure updates rarity and keeps figure id', () {
    final container = newEditableCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.updateCustomFigure(
      seriesId: 'custom_edit_1',
      figureId: 'custom_edit_1-f-1',
      name: 'Fig B',
      isSecret: true,
      rarityLabel: '1:96',
    );

    final fig = container.read(collectionNotifierProvider).shelfSeries.single.figures[1];
    expect(fig.id, 'custom_edit_1-f-1');
    expect(fig.isSecret, isTrue);
    expect(fig.rarityLabel, '1:96');
    expect(fig.rarity, '1:96');
  });

  test('updateCustomFigure updates image and keeps figure id', () {
    final container = newEditableCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.updateCustomFigure(
      seriesId: 'custom_edit_1',
      figureId: 'custom_edit_1-f-0',
      name: 'Fig A',
      isSecret: false,
      localImageUri: '/tmp/fig_a.jpg',
    );

    final fig = container.read(collectionNotifierProvider).shelfSeries.single.figures[0];
    expect(fig.id, 'custom_edit_1-f-0');
    expect(fig.localImageUri, '/tmp/fig_a.jpg');
  });

  test('updateCustomFigure preserves owned figure state', () {
    final container = newEditableCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.updateCustomFigure(
      seriesId: 'custom_edit_1',
      figureId: 'custom_edit_1-f-0',
      name: 'Owned Renamed',
      isSecret: false,
    );

    final snap = container.read(collectionNotifierProvider);
    expect(
      snap.trackedOrDefault('custom_edit_1-f-0').state,
      FigureCollectionState.owned,
    );
  });

  test('updateCustomFigure preserves wishlist figure state', () {
    final container = newEditableCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.updateCustomFigure(
      seriesId: 'custom_edit_1',
      figureId: 'custom_edit_1-f-1',
      name: 'Wishlist Renamed',
      isSecret: true,
      rarityLabel: '1:72',
    );

    final snap = container.read(collectionNotifierProvider);
    expect(
      snap.trackedOrDefault('custom_edit_1-f-1').state,
      FigureCollectionState.wishlist,
    );
  });

  test('updateCustomFigure preserves figure taxonomy fields', () {
    final container = newEditableCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.updateCustomFigure(
      seriesId: 'custom_edit_1',
      figureId: 'custom_edit_1-f-0',
      name: 'Taxonomy Safe',
      isSecret: false,
    );

    final fig = container.read(collectionNotifierProvider).shelfSeries.single.figures[0];
    expect(fig.taxonomyBrandId, 'dpl');
    expect(fig.taxonomyIpId, 'baby_three');
    expect(fig.imageKey, 'custom_edit_1-f-0');
  });

  test('updateCustomFigure does not change sibling figures', () {
    final container = newEditableCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);
    final before = container.read(collectionNotifierProvider).shelfSeries.single.figures[1];

    n.updateCustomFigure(
      seriesId: 'custom_edit_1',
      figureId: 'custom_edit_1-f-0',
      name: 'Only first changes',
      isSecret: false,
    );

    final after = container.read(collectionNotifierProvider).shelfSeries.single.figures[1];
    expect(after.id, before.id);
    expect(after.name, before.name);
    expect(after.isSecret, before.isSecret);
    expect(after.rarityLabel, before.rarityLabel);
  });

  test('updateCustomFigure ignores catalog-backed series', () {
    CollectionAppBootstrap.prime(
      CollectionSnapshot(
        shelfSeries: [testShelfSeries()],
        figureStates: const {},
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(collectionNotifierProvider.notifier);
    final before = container.read(collectionNotifierProvider).shelfSeries.single.figures.first;

    n.updateCustomFigure(
      seriesId: 'series_test',
      figureId: before.id,
      name: 'Hacked',
      isSecret: false,
    );

    final after = container.read(collectionNotifierProvider).shelfSeries.single.figures.first;
    expect(after.name, before.name);
  });

  test('updateCustomFigure leaves filters insights and journey unchanged', () {
    CollectionMemoryStore.instance.resetForTest();
    final container = newEditableCustomContainer();
    final beforeSnap = container.read(collectionNotifierProvider);
    final brandBefore = buildCollectionShelfBrandFilterOptions(beforeSnap.shelfSeries);
    final ipBefore = buildCollectionShelfIpFilterOptions(beforeSnap.shelfSeries);
    final profileBefore = interpretShelf(beforeSnap);
    final journeyBefore = buildCollectorJourneySummary(
      memory: CollectionMemoryStore.instance.cached,
      snapshot: beforeSnap,
    );
    final summaryBefore = CollectionAggregateStats.fromSnapshot(beforeSnap);

    container.read(collectionNotifierProvider.notifier).updateCustomFigure(
          seriesId: 'custom_edit_1',
          figureId: 'custom_edit_1-f-0',
          name: 'Metadata Only',
          isSecret: false,
          localImageUri: '/tmp/new.jpg',
        );

    final afterSnap = container.read(collectionNotifierProvider);
    expect(
      buildCollectionShelfBrandFilterOptions(afterSnap.shelfSeries),
      brandBefore,
    );
    expect(
      buildCollectionShelfIpFilterOptions(afterSnap.shelfSeries),
      ipBefore,
    );
    final profileAfter = interpretShelf(afterSnap);
    expect(profileAfter.dominantIpId, profileBefore.dominantIpId);
    expect(profileAfter.dominantBrandId, profileBefore.dominantBrandId);
    expect(profileAfter.shelfMood, profileBefore.shelfMood);

    final memoryBefore = CollectionMemoryStore.instance.cached;
    final journeyAfter = buildCollectorJourneySummary(
      memory: CollectionMemoryStore.instance.cached,
      snapshot: afterSnap,
    );
    expect(journeyAfter.ipUniversesExplored, journeyBefore.ipUniversesExplored);
    expect(
      journeyAfter.seriesExploredOverTime,
      journeyBefore.seriesExploredOverTime,
    );
    expect(journeyAfter.journeyAgeLabel, journeyBefore.journeyAgeLabel);
    expect(
      CollectionMemoryStore.instance.cached.ipSeriesDepth,
      memoryBefore.ipSeriesDepth,
    );

    expect(
      CollectionAggregateStats.fromSnapshot(afterSnap).inCollection,
      summaryBefore.inCollection,
    );
    expect(
      CollectionAggregateStats.fromSnapshot(afterSnap).wantListCount,
      summaryBefore.wantListCount,
    );
  });

  // ---------------------------------------------------------------------------
  // addCustomFigure
  // ---------------------------------------------------------------------------

  ProviderContainer newEmptyCustomContainer() {
    const seriesId = 'custom_empty_1';
    final series = ShelfSeries(
      id: seriesId,
      name: 'Solo Drop',
      brand: 'DPL',
      ipName: 'Baby Three',
      taxonomyBrandId: 'dpl',
      taxonomyIpId: 'baby_three',
      catalogTemplateId: null,
      imageKey: seriesId,
      figures: const [],
      shelfAccent: const Color(0xFFE4F2EA),
    );
    CollectionAppBootstrap.prime(
      CollectionSnapshot(shelfSeries: [series], figureStates: const {}),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('addCustomFigure appends to populated series with next index id', () {
    final container = newEditableCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.addCustomFigure(
      seriesId: 'custom_edit_1',
      name: 'Fig C',
      isSecret: false,
    );

    final series = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(series.figures.length, 3);
    expect(series.figures[2].id, 'custom_edit_1-f-2');
    expect(series.figures[2].name, 'Fig C');
    expect(series.figures[2].imageKey, 'custom_edit_1-f-2');
    expect(series.imageKey, 'custom_edit_1');
  });

  test('addCustomFigure appends first figure to empty custom series', () {
    final container = newEmptyCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.addCustomFigure(
      seriesId: 'custom_empty_1',
      name: 'Only One',
      isSecret: false,
    );

    final series = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(series.figures.length, 1);
    expect(series.figures.single.id, 'custom_empty_1-f-0');
    expect(series.figures.single.name, 'Only One');
  });

  test('addCustomFigure supports secret figure with rarity', () {
    final container = newEditableCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.addCustomFigure(
      seriesId: 'custom_edit_1',
      name: 'Secret Chase',
      isSecret: true,
      rarityLabel: '1:144',
    );

    final fig = container.read(collectionNotifierProvider).shelfSeries.single.figures.last;
    expect(fig.isSecret, isTrue);
    expect(fig.rarityLabel, '1:144');
    expect(fig.rarity, '1:144');
  });

  test('addCustomFigure supports local image uri', () {
    final container = newEditableCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.addCustomFigure(
      seriesId: 'custom_edit_1',
      name: 'Photo Fig',
      isSecret: false,
      localImageUri: '/tmp/photo_fig.jpg',
    );

    final fig = container.read(collectionNotifierProvider).shelfSeries.single.figures.last;
    expect(fig.localImageUri, '/tmp/photo_fig.jpg');
  });

  test('addCustomFigure copies series taxonomy and preserves siblings', () {
    final container = newEditableCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);
    final before = container.read(collectionNotifierProvider).shelfSeries.single.figures;

    n.addCustomFigure(
      seriesId: 'custom_edit_1',
      name: 'Fig C',
      isSecret: false,
    );

    final series = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(series.brand, 'DPL');
    expect(series.taxonomyBrandId, 'dpl');
    expect(series.taxonomyIpId, 'baby_three');
    expect(series.figures[0].name, before[0].name);
    expect(series.figures[1].name, before[1].name);
    expect(series.figures[2].taxonomyBrandId, 'dpl');
    expect(series.figures[2].taxonomyIpId, 'baby_three');
  });

  test('addCustomFigure preserves owned and wishlist figure states', () {
    final container = newEditableCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.addCustomFigure(
      seriesId: 'custom_edit_1',
      name: 'Fig C',
      isSecret: false,
    );

    final snap = container.read(collectionNotifierProvider);
    expect(
      snap.trackedOrDefault('custom_edit_1-f-0').state,
      FigureCollectionState.owned,
    );
    expect(
      snap.trackedOrDefault('custom_edit_1-f-1').state,
      FigureCollectionState.wishlist,
    );
    expect(snap.figureStates.containsKey('custom_edit_1-f-2'), isFalse);
  });

  test('addCustomFigure ignores catalog-backed series', () {
    CollectionAppBootstrap.prime(
      CollectionSnapshot(
        shelfSeries: [testShelfSeries()],
        figureStates: const {},
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final before = container.read(collectionNotifierProvider).shelfSeries.single;

    container.read(collectionNotifierProvider.notifier).addCustomFigure(
          seriesId: 'series_test',
          name: 'Injected',
          isSecret: false,
        );

    final after = container.read(collectionNotifierProvider).shelfSeries.single;
    expect(after.figures.length, before.figures.length);
  });

  test('addCustomFigure no-ops on empty name', () {
    final container = newEditableCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.addCustomFigure(
      seriesId: 'custom_edit_1',
      name: '   ',
      isSecret: false,
    );

    expect(
      container.read(collectionNotifierProvider).shelfSeries.single.figures.length,
      2,
    );
  });

  test('addCustomFigure survives persistence round-trip', () async {
    SharedPreferences.setMockInitialValues({});
    final container = newEditableCustomContainer();
    final n = container.read(collectionNotifierProvider.notifier);

    n.addCustomFigure(
      seriesId: 'custom_edit_1',
      name: 'Persisted Fig',
      isSecret: true,
      rarityLabel: '1:96',
      localImageUri: '/tmp/persisted.jpg',
    );

    final snap = container.read(collectionNotifierProvider);
    await CollectionSnapshotStorage.save(snap);
    final loaded = await CollectionSnapshotStorage.load();

    final series = loaded!.shelfSeries.single;
    expect(series.figures.length, 3);
    final fig = series.figures[2];
    expect(fig.id, 'custom_edit_1-f-2');
    expect(fig.name, 'Persisted Fig');
    expect(fig.isSecret, isTrue);
    expect(fig.rarityLabel, '1:96');
    expect(fig.localImageUri, '/tmp/persisted.jpg');
    expect(fig.taxonomyBrandId, 'dpl');
  });

  test('addCustomFigure leaves filters insights and journey unchanged', () {
    CollectionMemoryStore.instance.resetForTest();
    final container = newEditableCustomContainer();
    final beforeSnap = container.read(collectionNotifierProvider);
    final brandBefore = buildCollectionShelfBrandFilterOptions(beforeSnap.shelfSeries);
    final ipBefore = buildCollectionShelfIpFilterOptions(beforeSnap.shelfSeries);
    final profileBefore = interpretShelf(beforeSnap);

    container.read(collectionNotifierProvider.notifier).addCustomFigure(
          seriesId: 'custom_edit_1',
          name: 'Extra Fig',
          isSecret: false,
        );

    final afterSnap = container.read(collectionNotifierProvider);
    expect(
      buildCollectionShelfBrandFilterOptions(afterSnap.shelfSeries),
      brandBefore,
    );
    expect(
      buildCollectionShelfIpFilterOptions(afterSnap.shelfSeries),
      ipBefore,
    );
    final profileAfter = interpretShelf(afterSnap);
    expect(profileAfter.dominantIpId, profileBefore.dominantIpId);
    expect(profileAfter.dominantBrandId, profileBefore.dominantBrandId);
  });

  // ---------------------------------------------------------------------------
  // Write coalescing / debounce
  // ---------------------------------------------------------------------------

  test(
    'rapid cycleFigure calls produce correct final UI state immediately',
    () {
      final container = newContainer();
      final n = container.read(collectionNotifierProvider.notifier);

      // Simulate rapid successive taps: none → wishlist → owned → none.
      n.cycleFigure('fig_cycle');
      n.cycleFigure('fig_cycle');
      n.cycleFigure('fig_cycle');

      // UI state should reflect all taps immediately (no debounce on state).
      final snap = container.read(collectionNotifierProvider);
      expect(snap.figureStates.containsKey('fig_cycle'), isFalse,
          reason: 'three cycles (none→wishlist→owned→none) should clear the state');
    },
  );

  test(
    'persistence is deferred but flushed synchronously on notifier dispose',
    () async {
      SharedPreferences.setMockInitialValues({});
      final container = newContainer();
      final n = container.read(collectionNotifierProvider.notifier);

      n.cycleFigure('fig_cycle'); // wishlist
      n.cycleFigure('fig_cycle'); // owned

      // Before the debounce timer fires, prefs might be empty or stale.
      // Disposing the container triggers _flushPendingPersistence immediately.
      container.dispose();

      // After dispose the flush is awaited via the unawaited save chain.
      // Allow microtask/async queue to settle.
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('collection_snapshot_v1');
      // The snapshot should have been persisted (not null).
      expect(raw, isNotNull,
          reason: 'dispose should flush pending persistence');
    },
  );

  test(
    'fakeAsync: persistence timer fires after debounce window',
    () {
      fakeAsync((async) {
        SharedPreferences.setMockInitialValues({});
        final container = newContainer();
        final n = container.read(collectionNotifierProvider.notifier);

        n.cycleFigure('fig_cycle'); // wishlist
        n.cycleFigure('fig_cycle'); // owned

        // UI state is already correct before the timer fires.
        expect(
          container
              .read(collectionNotifierProvider)
              .trackedOrDefault('fig_cycle')
              .state,
          FigureCollectionState.owned,
        );

        // Advance past the debounce window without triggering async I/O.
        async.elapse(const Duration(milliseconds: 500));

        // State should remain unchanged after the timer fires.
        expect(
          container
              .read(collectionNotifierProvider)
              .trackedOrDefault('fig_cycle')
              .state,
          FigureCollectionState.owned,
        );

        container.dispose();
      });
    },
  );

  // ---------------------------------------------------------------------------
  // Memory flush on dispose (journey / collector type milestones)
  // ---------------------------------------------------------------------------

  group('pending memory transitions on persistence flush', () {
    test('scenario A: debounce fires then dispose records transition once', () {
      fakeAsync((async) {
        CollectionMemoryStore.instance.resetForTest();
        final container = newEmptyMemoryContainer();
        addTearDown(container.dispose);
        final n = container.read(collectionNotifierProvider.notifier);

        n.addSeriesFromTemplate(
          testCatalogTemplate(templateId: 'memory_tpl_a'),
        );
        async.elapse(const Duration(milliseconds: 400));
        async.flushMicrotasks();

        final depthAfterDebounce =
            CollectionMemoryStore.instance.cached.ipSeriesDepth;
        expect(depthAfterDebounce['the_monsters'], 1);
        expect(
          CollectionMemoryStore.instance.cached.firstSeriesAddedAtMs,
          isNotNull,
        );

        container.dispose();
        async.flushMicrotasks();

        expect(
          CollectionMemoryStore.instance.cached.ipSeriesDepth['the_monsters'],
          1,
          reason: 'dispose after debounce must not duplicate ip depth',
        );
      });
    });

    test('scenario B: dispose before debounce still records transition', () {
      fakeAsync((async) {
        CollectionMemoryStore.instance.resetForTest();
        final container = newEmptyMemoryContainer();
        final n = container.read(collectionNotifierProvider.notifier);

        n.addSeriesFromTemplate(
          testCatalogTemplate(templateId: 'memory_tpl_b'),
        );

        container.dispose();
        async.flushMicrotasks();

        expect(
          CollectionMemoryStore.instance.cached.firstSeriesAddedAtMs,
          isNotNull,
          reason: 'dispose should flush pending recordTransitions',
        );
        expect(
          CollectionMemoryStore.instance.cached.ipSeriesDepth['the_monsters'],
          1,
        );
      });
    });

    test(
      'scenario C: multiple mutations in debounce window record one net transition',
      () {
        fakeAsync((async) {
          CollectionMemoryStore.instance.resetForTest();
          final container = newEmptyMemoryContainer();
          final n = container.read(collectionNotifierProvider.notifier);

          n.addCustomSeries(
            seriesName: 'Custom A',
            figures: const [CustomFigureDraft(displayName: 'Fig A')],
          );
          n.addCustomSeries(
            seriesName: 'Custom B',
            ipDisplayName: 'Other IP',
            figures: const [CustomFigureDraft(displayName: 'Fig B')],
          );

          expect(
            container.read(collectionNotifierProvider).shelfSeries.length,
            2,
          );

          container.dispose();
          async.flushMicrotasks();
          final depth =
              CollectionMemoryStore.instance.cached.ipSeriesDepth;
          expect(
            depth.values.fold<int>(0, (sum, c) => sum + c),
            2,
            reason: 'two new series in one coalesced transition',
          );
          expect(depth.length, 2);
        });
      },
    );
  });
}
