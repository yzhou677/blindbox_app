import 'package:blindbox_app/features/official_feed/data/firestore_official_feed_loader.dart';
import 'package:blindbox_app/features/official_feed/data/official_feed_repository.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_sources.dart';
import 'package:flutter_test/flutter_test.dart';

OfficialFeedItem _item({
  required String id,
  required String sourceId,
  String? title,
}) {
  return OfficialFeedItem(
    id: id,
    sourceId: sourceId,
    sourceLabel: OfficialFeedSources.displayLabel(sourceId),
    title: title ?? 'Title $id',
    imageUrl: 'https://cdn.example.com/$id.png',
    officialUrl: 'https://cdn.example.com/out/$id',
    publishedAt: DateTime.utc(2026, 7, 1),
    contentHash: 'hash_$id',
  );
}

void main() {
  setUp(OfficialFeedRepository.debugClearLastGoodCache);

  group('dedupeOfficialFeedItemsById', () {
    test('keeps first occurrence of each stable id', () {
      final a1 = _item(id: 'a', sourceId: OfficialFeedSources.popmartUs);
      final a2 = _item(
        id: 'a',
        sourceId: OfficialFeedSources.popmartUs,
        title: 'Duplicate title should not win',
      );
      final b = _item(id: 'b', sourceId: OfficialFeedSources.popmartUs);

      final out = dedupeOfficialFeedItemsById([a1, a2, b]);
      expect(out.map((e) => e.id), ['a', 'b']);
      expect(out.first.title, a1.title);
    });
  });

  group('OfficialFeedRepository partial failure', () {
    test('one rejected brand does not discard sibling successes', () async {
      final repo = OfficialFeedRepository(
        loader: ({required sourceId, limit = 12}) async {
          if (sourceId == OfficialFeedSources.tntspaceUs) {
            throw StateError('firestore unavailable');
          }
          return [_item(id: '${sourceId}_1', sourceId: sourceId)];
        },
      );

      final catalog = await repo.loadCuratedHomeCatalog();
      expect(catalog.itemsFor(OfficialFeedSources.popmartUs), hasLength(1));
      expect(catalog.itemsFor(OfficialFeedSources.toptoyUs), hasLength(1));
      expect(catalog.itemsFor(OfficialFeedSources.sonnyangelUs), hasLength(1));
      expect(catalog.itemsFor(OfficialFeedSources.tntspaceUs), isEmpty);
      expect(catalog.hasAnyItems, isTrue);
      expect(catalog.showBrandFilters, isTrue);
      expect(catalog.availableSources, [
        OfficialFeedSources.popmartUs,
        OfficialFeedSources.toptoyUs,
        OfficialFeedSources.sonnyangelUs,
      ]);
    });

    test(
      'uses last-good on failure without clearing cache after a success',
      () async {
        var failTnt = false;
        final repo = OfficialFeedRepository(
          loader: ({required sourceId, limit = 12}) async {
            if (sourceId == OfficialFeedSources.tntspaceUs && failTnt) {
              throw StateError('timeout');
            }
            if (sourceId == OfficialFeedSources.tntspaceUs) {
              return [_item(id: 'tnt_cached', sourceId: sourceId)];
            }
            return const [];
          },
        );

        final first = await repo.loadCuratedHomeCatalog();
        expect(
          first.itemsFor(OfficialFeedSources.tntspaceUs).single.id,
          'tnt_cached',
        );

        failTnt = true;
        final second = await repo.loadCuratedHomeCatalog();
        expect(
          second.itemsFor(OfficialFeedSources.tntspaceUs).single.id,
          'tnt_cached',
        );
      },
    );

    test(
      'preserves curated brand map order despite completion order',
      () async {
        final repo = OfficialFeedRepository(
          loader: ({required sourceId, limit = 12}) async {
            // Reverse latency vs curated order.
            final delayMs = switch (sourceId) {
              OfficialFeedSources.popmartUs => 30,
              OfficialFeedSources.tntspaceUs => 10,
              OfficialFeedSources.toptoyUs => 1,
              _ => 0,
            };
            await Future<void>.delayed(Duration(milliseconds: delayMs));
            return [_item(id: '${sourceId}_1', sourceId: sourceId)];
          },
        );

        final catalog = await repo.loadCuratedHomeCatalog();
        expect(
          catalog.bySource.keys.toList(),
          OfficialFeedSources.curatedHomeSources,
        );
        expect(
          OfficialFeedSources.resolveSelection(
            availableSourceIds: catalog.availableSources,
          ),
          OfficialFeedSources.popmartUs,
        );
      },
    );
  });
}
