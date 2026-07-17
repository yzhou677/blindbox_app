import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as seed;
import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_stat_keys.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reason_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/collection_fixtures.dart';

ShelfSeries _seriesWithFigures({
  required String id,
  required List<ShelfFigure> figures,
  String? brandId,
  String? ipId,
  String? catalogTemplateId,
  bool customLocal = false,
  String? notes,
  String? customCover,
}) {
  // Product: notes / covers exist only on custom series — never on catalog rows.
  assert(
    customLocal || (notes == null && customCover == null),
    'notes/customCover require customLocal: true (catalog series have no notes UI)',
  );
  return ShelfSeries(
    id: id,
    name: 'Series $id',
    brand: 'POP MART',
    ipName: 'IP',
    figures: figures,
    shelfAccent: const Color(0xFFE4F2EA),
    taxonomyBrandId: brandId ?? 'pop_mart',
    taxonomyIpId: ipId ?? 'the_monsters',
    catalogTemplateId: customLocal
        ? null
        : (catalogTemplateId ?? 'catalog_$id'),
    notes: customLocal ? notes : null,
    customCoverImageUri: customLocal ? customCover : null,
  );
}

TrackedFigure _owned(String id) =>
    TrackedFigure(figureId: id, state: FigureCollectionState.owned);

TrackedFigure _wish(String id) =>
    TrackedFigure(figureId: id, state: FigureCollectionState.wishlist);

WishlistedCatalogSeries _wishlistedSeries(String id) => WishlistedCatalogSeries(
  catalogSeriesId: id,
  name: 'Wishlist $id',
  brand: 'POP MART',
  ipName: 'IP',
  imageKey: id,
  addedAtMicros: 1,
  taxonomyBrandId: 'pop_mart',
  taxonomyIpId: 'the_monsters',
);

void main() {
  test('empty shelf resolves to wanderer', () {
    final snap = CollectionSnapshot.emptyTest();
    final profile = interpretShelf(snap);
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: profile,
      revealedAt: DateTime(2026, 1, 1),
    );
    expect(identity.archetypeId, CollectorTypeArchetypeId.wanderer);
    expect(identity.reasonKey, CollectorTypeReasonKey.stillUnfolding);
  });

  test('wishlist remains Dreamer-only and does not change other scores', () {
    final series = _seriesWithFigures(
      id: 'dream',
      figures: const [
        ShelfFigure(
          id: 'owned',
          seriesId: 'dream',
          name: 'Owned',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'wish_a',
          seriesId: 'dream',
          name: 'Wish A',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'wish_b',
          seriesId: 'dream',
          name: 'Wish B',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final base = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: {'owned': _owned('owned')},
    );
    final withWishlist = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: {
        'owned': _owned('owned'),
        'wish_a': _wish('wish_a'),
        'wish_b': _wish('wish_b'),
      },
    );

    final baseResolution = resolveCollectorType(
      snapshot: base,
      profile: interpretShelf(base),
      revealedAt: DateTime(2026, 1, 1),
    );
    final wishlistResolution = resolveCollectorType(
      snapshot: withWishlist,
      profile: interpretShelf(withWishlist),
      revealedAt: DateTime(2026, 1, 1),
    );

    expect(wishlistResolution.archetypeId, CollectorTypeArchetypeId.dreamer);
    expect(wishlistResolution.reasonKey, CollectorTypeReasonKey.highWishlist);
    for (final id in CollectorTypeArchetypeId.values) {
      if (id == CollectorTypeArchetypeId.dreamer) continue;
      expect(
        wishlistResolution.scores[id],
        baseResolution.scores[id],
        reason: '$id should not use wishlist scoring',
      );
    }
  });

  test('dreamer uses started series instead of raw collection rows', () {
    final unstartedRows = [
      for (var i = 0; i < 4; i++)
        _seriesWithFigures(
          id: 'unstarted_$i',
          figures: [
            ShelfFigure(
              id: 'unstarted_${i}_fig',
              seriesId: 'unstarted_$i',
              name: 'Unstarted $i',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
        ),
    ];
    final snap = CollectionSnapshot(
      shelfSeries: unstartedRows,
      figureStates: const {},
      seriesWishlist: [
        _wishlistedSeries('wish_series_a'),
        _wishlistedSeries('wish_series_b'),
      ],
    );

    expect(snap.startedSeriesCount, 0);

    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );

    expect(identity.archetypeId, CollectorTypeArchetypeId.dreamer);
    expect(identity.reasonKey, CollectorTypeReasonKey.highWishlist);
  });

  test('unstarted collection series can define Dreamer intent', () {
    final snap = CollectionSnapshot(
      shelfSeries: [
        _seriesWithFigures(
          id: 'planned_a',
          figures: const [
            ShelfFigure(
              id: 'planned_a_fig',
              seriesId: 'planned_a',
              name: 'Planned A',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
        ),
        _seriesWithFigures(
          id: 'planned_b',
          figures: const [
            ShelfFigure(
              id: 'planned_b_fig',
              seriesId: 'planned_b',
              name: 'Planned B',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
        ),
      ],
      figureStates: const {},
    );

    expect(snap.startedSeriesCount, 0);
    expect(snap.unstartedSeriesCount, 2);

    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );

    expect(identity.archetypeId, CollectorTypeArchetypeId.dreamer);
  });

  test('pure wishlist series with no collection resolves to Dreamer', () {
    final snap = CollectionSnapshot(
      shelfSeries: const [],
      figureStates: const {},
      seriesWishlist: [
        _wishlistedSeries('wish_series_a'),
        _wishlistedSeries('wish_series_b'),
      ],
    );

    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );

    expect(identity.archetypeId, CollectorTypeArchetypeId.dreamer);
    expect(
      identity.scores[CollectorTypeArchetypeId.dreamer],
      closeTo(38 + 1.0 * 40, 0.001),
    );
  });

  test('dreamer denominator combines all future intent sources', () {
    final started = _seriesWithFigures(
      id: 'started',
      figures: const [
        ShelfFigure(
          id: 'owned',
          seriesId: 'started',
          name: 'Owned',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'wishlist_figure',
          seriesId: 'started',
          name: 'Wishlist Figure',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final unstarted = _seriesWithFigures(
      id: 'unstarted',
      figures: const [
        ShelfFigure(
          id: 'planned',
          seriesId: 'unstarted',
          name: 'Planned',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [started, unstarted],
      figureStates: {
        'owned': _owned('owned'),
        'wishlist_figure': _wish('wishlist_figure'),
      },
      seriesWishlist: [_wishlistedSeries('wish_series_a')],
    );

    expect(snap.startedSeriesCount, 1);
    expect(snap.unstartedSeriesCount, 1);
    expect(snap.totalWishlistFigures, 1);
    expect(snap.totalWishlistedSeries, 1);

    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );

    expect(identity.archetypeId, CollectorTypeArchetypeId.dreamer);
    expect(
      identity.scores[CollectorTypeArchetypeId.dreamer],
      closeTo(38 + (3 / 4) * 40, 0.001),
    );
  });

  test(
    'first owned figure starts a series and changes Dreamer denominator',
    () {
      final series = _seriesWithFigures(
        id: 'started',
        figures: const [
          ShelfFigure(
            id: 'owned',
            seriesId: 'started',
            name: 'Owned',
            rarity: 'Regular',
            isSecret: false,
          ),
          ShelfFigure(
            id: 'unowned',
            seriesId: 'started',
            name: 'Unowned',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
      );
      final snap = CollectionSnapshot(
        shelfSeries: [series],
        figureStates: {'owned': _owned('owned')},
        seriesWishlist: [
          _wishlistedSeries('wish_series_a'),
          _wishlistedSeries('wish_series_b'),
        ],
      );

      expect(snap.startedSeriesCount, 1);

      final identity = resolveCollectorType(
        snapshot: snap,
        profile: interpretShelf(snap),
        revealedAt: DateTime(2026, 1, 1),
      );

      expect(identity.archetypeId, CollectorTypeArchetypeId.dreamer);
      expect(
        identity.scores[CollectorTypeArchetypeId.dreamer],
        closeTo(38 + (2 / 3) * 40, 0.001),
      );
    },
  );

  test('wishlisted series do not change non-Dreamer scores', () {
    final shelf = <ShelfSeries>[
      for (var i = 0; i < 5; i++)
        _seriesWithFigures(
          id: 'hunter_$i',
          ipId: 'ip_$i',
          figures: [
            ShelfFigure(
              id: 'secret_$i',
              seriesId: 'hunter_$i',
              name: 'Secret $i',
              rarity: 'Secret',
              isSecret: true,
            ),
            ShelfFigure(
              id: 'regular_$i',
              seriesId: 'hunter_$i',
              name: 'Regular $i',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
        ),
    ];
    final states = {
      for (var i = 0; i < 5; i++) 'secret_$i': _owned('secret_$i'),
    };
    final base = CollectionSnapshot(shelfSeries: shelf, figureStates: states);
    final withWishlist = CollectionSnapshot(
      shelfSeries: shelf,
      figureStates: states,
      seriesWishlist: [
        _wishlistedSeries('wish_series_a'),
        _wishlistedSeries('wish_series_b'),
      ],
    );

    final baseResolution = resolveCollectorType(
      snapshot: base,
      profile: interpretShelf(base),
      revealedAt: DateTime(2026, 1, 1),
    );
    final wishlistResolution = resolveCollectorType(
      snapshot: withWishlist,
      profile: interpretShelf(withWishlist),
      revealedAt: DateTime(2026, 1, 1),
    );

    expect(baseResolution.archetypeId, CollectorTypeArchetypeId.hunter);
    expect(wishlistResolution.archetypeId, CollectorTypeArchetypeId.hunter);
    for (final id in CollectorTypeArchetypeId.values) {
      if (id == CollectorTypeArchetypeId.dreamer) continue;
      expect(
        wishlistResolution.scores[id],
        baseResolution.scores[id],
        reason: '$id should not use wishlisted series scoring',
      );
    }
  });

  test('unstarted series do not form Wanderer shelf breadth', () {
    final series = _seriesWithFigures(
      id: 'planned',
      figures: const [
        ShelfFigure(
          id: 'planned_figure',
          seriesId: 'planned',
          name: 'Planned Figure',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'unowned',
          seriesId: 'started',
          name: 'Unowned',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: const {},
    );

    expect(snap.startedSeriesCount, 0);

    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );

    expect(identity.archetypeId, CollectorTypeArchetypeId.wanderer);
  });

  test('unstarted series do not increase Curator IP breadth', () {
    final series = [
      for (final entry in [
        ('started_a', 'ip_a'),
        ('started_b', 'ip_b'),
        ('unstarted_c', 'ip_c'),
      ])
        _seriesWithFigures(
          id: entry.$1,
          ipId: entry.$2,
          figures: [
            ShelfFigure(
              id: '${entry.$1}_a',
              seriesId: entry.$1,
              name: 'A',
              rarity: 'Regular',
              isSecret: false,
            ),
            ShelfFigure(
              id: '${entry.$1}_b',
              seriesId: entry.$1,
              name: 'B',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
        ),
    ];
    final states = {
      for (final s in series.take(2))
        for (final f in s.figures) f.id: _owned(f.id),
    };
    final snap = CollectionSnapshot(shelfSeries: series, figureStates: states);

    expect(snap.startedSeriesCount, 2);

    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );

    expect(identity.scores[CollectorTypeArchetypeId.curator], 0);
  });

  test('Curator threshold still uses three started IPs', () {
    final series = [
      for (var i = 0; i < 3; i++)
        _seriesWithFigures(
          id: 'started_$i',
          ipId: 'ip_$i',
          figures: [
            ShelfFigure(
              id: 'started_${i}_a',
              seriesId: 'started_$i',
              name: 'A',
              rarity: 'Regular',
              isSecret: false,
            ),
            ShelfFigure(
              id: 'started_${i}_b',
              seriesId: 'started_$i',
              name: 'B',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
        ),
    ];
    final states = {
      for (final s in series) s.figures.first.id: _owned(s.figures.first.id),
    };
    final snap = CollectionSnapshot(shelfSeries: series, figureStates: states);

    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );

    expect(identity.scores[CollectorTypeArchetypeId.curator], greaterThan(0));
  });

  test('unstarted series do not increase Loyalist IP dominance', () {
    final series = [
      _seriesWithFigures(
        id: 'unstarted_a',
        ipId: 'dimoo',
        figures: const [
          ShelfFigure(
            id: 'unstarted_a_fig',
            seriesId: 'unstarted_a',
            name: 'Unstarted A',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
      ),
      _seriesWithFigures(
        id: 'unstarted_b',
        ipId: 'dimoo',
        figures: const [
          ShelfFigure(
            id: 'unstarted_b_fig',
            seriesId: 'unstarted_b',
            name: 'Unstarted B',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
      ),
      _seriesWithFigures(
        id: 'started_other',
        ipId: 'hirono',
        figures: const [
          ShelfFigure(
            id: 'started_other_fig',
            seriesId: 'started_other',
            name: 'Started Other',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
      ),
    ];
    final snap = CollectionSnapshot(
      shelfSeries: series,
      figureStates: {'started_other_fig': _owned('started_other_fig')},
    );

    expect(snap.startedSeriesCount, 1);

    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );

    expect(identity.scores[CollectorTypeArchetypeId.loyalist], 0);
  });

  test('Loyalist threshold still uses started IP dominance', () {
    final series = [
      for (var i = 0; i < 2; i++)
        _seriesWithFigures(
          id: 'dimoo_$i',
          ipId: 'dimoo',
          figures: [
            ShelfFigure(
              id: 'dimoo_${i}_a',
              seriesId: 'dimoo_$i',
              name: 'A',
              rarity: 'Regular',
              isSecret: false,
            ),
            ShelfFigure(
              id: 'dimoo_${i}_b',
              seriesId: 'dimoo_$i',
              name: 'B',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
        ),
      _seriesWithFigures(
        id: 'other',
        ipId: 'other',
        figures: const [
          ShelfFigure(
            id: 'other_a',
            seriesId: 'other',
            name: 'A',
            rarity: 'Regular',
            isSecret: false,
          ),
          ShelfFigure(
            id: 'other_b',
            seriesId: 'other',
            name: 'B',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
      ),
    ];
    final states = {
      for (final s in series) s.figures.first.id: _owned(s.figures.first.id),
    };
    final snap = CollectionSnapshot(shelfSeries: series, figureStates: states);

    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );

    expect(identity.scores[CollectorTypeArchetypeId.loyalist], greaterThan(0));
  });

  test('Trend Chaser still uses raw catalog series recency', () {
    final now = DateTime(2026, 7, 1);
    final series = [
      for (final id in ['recent_a', 'recent_b', 'old_a'])
        _seriesWithFigures(
          id: id,
          catalogTemplateId: id,
          figures: [
            ShelfFigure(
              id: '${id}_figure',
              seriesId: id,
              name: 'Figure $id',
              rarity: 'Regular',
              isSecret: false,
            ),
            ShelfFigure(
              id: '${id}_other',
              seriesId: id,
              name: 'Other $id',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
        ),
    ];
    final catalog = CatalogSeedBundle(
      brands: const [],
      ips: const [],
      series: const [
        seed.CatalogSeries(
          id: 'recent_a',
          brandId: 'pop_mart',
          ipId: 'ip_a',
          displayName: 'Recent A',
          releaseDate: '2026-06-01',
          isBlindBox: true,
          imageKey: 'recent_a',
        ),
        seed.CatalogSeries(
          id: 'recent_b',
          brandId: 'pop_mart',
          ipId: 'ip_b',
          displayName: 'Recent B',
          releaseDate: '2026-06-15',
          isBlindBox: true,
          imageKey: 'recent_b',
        ),
        seed.CatalogSeries(
          id: 'old_a',
          brandId: 'pop_mart',
          ipId: 'ip_c',
          displayName: 'Old A',
          releaseDate: '2025-01-01',
          isBlindBox: true,
          imageKey: 'old_a',
        ),
      ],
      figures: const [],
    );
    final snap = CollectionSnapshot(
      shelfSeries: series,
      figureStates: const {},
    );

    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      catalog: catalog,
      revealedAt: now,
    );

    expect(snap.startedSeriesCount, 0);
    expect(
      identity.scores[CollectorTypeArchetypeId.trendChaser],
      closeTo(38 + (2 / 3) * 40 + 2 * 4, 0.001),
    );
  });

  test('lucky one when early shelf has multiple secrets', () {
    final series = _seriesWithFigures(
      id: 's1',
      figures: [
        const ShelfFigure(
          id: 'a',
          seriesId: 's1',
          name: 'Secret A',
          rarity: 'Secret',
          isSecret: true,
        ),
        const ShelfFigure(
          id: 'b',
          seriesId: 's1',
          name: 'Secret B',
          rarity: 'Secret',
          isSecret: true,
        ),
        const ShelfFigure(
          id: 'c',
          seriesId: 's1',
          name: 'Regular',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: {'a': _owned('a'), 'b': _owned('b')},
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );
    expect(identity.archetypeId, CollectorTypeArchetypeId.luckyOne);
    expect(identity.reasonKey, CollectorTypeReasonKey.fortunateSecrets);
  });

  test('hunter when shelf grows past early stage with multiple secrets', () {
    final shelf = <ShelfSeries>[
      for (var i = 0; i < 5; i++)
        _seriesWithFigures(
          id: 's$i',
          ipId: 'ip_$i',
          figures: [
            ShelfFigure(
              id: 'r$i',
              seriesId: 's$i',
              name: 'Regular $i',
              rarity: 'Regular',
              isSecret: false,
            ),
            if (i < 4)
              ShelfFigure(
                id: 'sec$i',
                seriesId: 's$i',
                name: 'Secret $i',
                rarity: 'Secret',
                isSecret: true,
              ),
          ],
        ),
    ];
    final snap = CollectionSnapshot(
      shelfSeries: shelf,
      // 2/4 secret slots = 50% on >4 series → Hunter
      figureStates: {'sec0': _owned('sec0'), 'sec1': _owned('sec1')},
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );
    expect(identity.archetypeId, CollectorTypeArchetypeId.hunter);
    expect(identity.reasonKey, CollectorTypeReasonKey.manySecrets);
  });

  test('small fully owned shelf resolves to minimalist, not completionist', () {
    final series = _seriesWithFigures(
      id: 's1',
      figures: [
        const ShelfFigure(
          id: 'a',
          seriesId: 's1',
          name: 'A',
          rarity: 'Regular',
          isSecret: false,
        ),
        const ShelfFigure(
          id: 'b',
          seriesId: 's1',
          name: 'B',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final series2 = _seriesWithFigures(
      id: 's2',
      ipId: 'hirono',
      figures: [
        const ShelfFigure(
          id: 'c',
          seriesId: 's2',
          name: 'C',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [series, series2],
      figureStates: {'a': _owned('a'), 'b': _owned('b'), 'c': _owned('c')},
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );
    expect(identity.archetypeId, CollectorTypeArchetypeId.minimalist);
    expect(identity.scores[CollectorTypeArchetypeId.completionist], 0);
  });

  test('wishlist-heavy shelf resolves to dreamer', () {
    final series = _seriesWithFigures(
      id: 's1',
      figures: [
        const ShelfFigure(
          id: 'a',
          seriesId: 's1',
          name: 'A',
          rarity: 'R',
          isSecret: false,
        ),
        const ShelfFigure(
          id: 'b',
          seriesId: 's1',
          name: 'B',
          rarity: 'R',
          isSecret: false,
        ),
        const ShelfFigure(
          id: 'c',
          seriesId: 's1',
          name: 'C',
          rarity: 'R',
          isSecret: false,
        ),
        const ShelfFigure(
          id: 'd',
          seriesId: 's1',
          name: 'D',
          rarity: 'R',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: {
        'a': _wish('a'),
        'b': _wish('b'),
        'c': _wish('c'),
        'd': _wish('d'),
      },
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );
    expect(identity.archetypeId, CollectorTypeArchetypeId.dreamer);
  });

  test('signature hash changes when ownership changes', () {
    final series = testShelfSeries();
    final before = CollectionSnapshot(shelfSeries: [series], figureStates: {});
    final after = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: {'fig_test_0': _owned('fig_test_0')},
    );
    expect(
      computeCollectorTypeSignatureHash(before),
      isNot(computeCollectorTypeSignatureHash(after)),
    );
  });

  test('signature hash changes when a second brand series is added', () {
    final popMart = testShelfSeries(
      id: 's_pop',
      catalogTemplateId: 'catalog_pop',
      taxonomyBrandId: 'pop_mart',
      brand: 'POP MART',
    );
    final nommi = testShelfSeries(
      id: 's_nommi',
      name: 'NOMMI Series',
      catalogTemplateId: 'catalog_nommi',
      taxonomyBrandId: 'toptoy',
      brand: 'TOPTOY',
      taxonomyIpId: 'nommi',
      ipName: 'NOMMI',
      figures: const [
        ShelfFigure(
          id: 'fig_nommi_0',
          seriesId: 's_nommi',
          name: 'Nommi Fig',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final before = CollectionSnapshot(
      shelfSeries: [popMart],
      figureStates: const {},
    );
    final after = CollectionSnapshot(
      shelfSeries: [popMart, nommi],
      figureStates: const {},
    );
    expect(
      computeCollectorTypeSignatureHash(before),
      isNot(computeCollectorTypeSignatureHash(after)),
    );

    final identity = resolveCollectorType(
      snapshot: after,
      profile: interpretShelf(after),
      revealedAt: DateTime(2026, 1, 1),
    );
    expect(identity.stats.brandBreakdown.length, 2);
    expect(
      identity.stats.brandBreakdown.keys.map(canonicalizeStatKey).toSet(),
      containsAll(['popmart', 'toptoy']),
    );
  });

  test('brand breakdown merges variant taxonomy keys', () {
    final s1 = testShelfSeries(
      id: 's1',
      taxonomyBrandId: 'pop_mart',
      brand: 'POP MART',
    );
    final s2 = testShelfSeries(
      id: 's2',
      taxonomyBrandId: 'POP MART',
      brand: 'Popmart',
    );
    final snap = CollectionSnapshot(
      shelfSeries: [s1, s2],
      figureStates: const {},
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );
    expect(identity.stats.brandBreakdown.length, 1);
    expect(identity.stats.brandBreakdown.values.single, 2);
    expect(
      canonicalizeStatKey(identity.stats.brandBreakdown.keys.single),
      'popmart',
    );
  });

  test('trend chaser with recent catalog releases', () {
    final catalog = CatalogSeedBundle(
      brands: const [],
      ips: const [],
      series: [
        seed.CatalogSeries(
          id: 'recent_series',
          brandId: 'pop_mart',
          ipId: 'the_monsters',
          displayName: 'Recent',
          releaseDate: '2026-03-01',
          isBlindBox: true,
          imageKey: 'recent_series',
        ),
        seed.CatalogSeries(
          id: 'recent_series_2',
          brandId: 'finding_unicorn',
          ipId: 'hirono',
          displayName: 'Recent 2',
          releaseDate: '2026-02-15',
          isBlindBox: true,
          imageKey: 'recent_series_2',
        ),
      ],
      figures: const [],
    );
    final s1 = _seriesWithFigures(
      id: 's1',
      catalogTemplateId: 'recent_series',
      figures: [
        const ShelfFigure(
          id: 'a',
          seriesId: 's1',
          name: 'A',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final s2 = _seriesWithFigures(
      id: 's2',
      catalogTemplateId: 'recent_series_2',
      brandId: 'finding_unicorn',
      ipId: 'hirono',
      figures: [
        const ShelfFigure(
          id: 'b',
          seriesId: 's2',
          name: 'B',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [s1, s2],
      figureStates: {'a': _owned('a')},
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      catalog: catalog,
      revealedAt: DateTime(2026, 5, 1),
    );
    expect(identity.archetypeId, CollectorTypeArchetypeId.trendChaser);
  });

  test('single-IP shelf does not become curator from Journey depth', () {
    final s1 = _seriesWithFigures(
      id: 's1',
      brandId: 'dreams_inc',
      ipId: 'smiski',
      figures: const [
        ShelfFigure(
          id: 'a',
          seriesId: 's1',
          name: 'A',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'a2',
          seriesId: 's1',
          name: 'A2',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final s2 = _seriesWithFigures(
      id: 's2',
      brandId: 'dreams_inc',
      ipId: 'smiski',
      figures: const [
        ShelfFigure(
          id: 'b',
          seriesId: 's2',
          name: 'B',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'b2',
          seriesId: 's2',
          name: 'B2',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final s3 = _seriesWithFigures(
      id: 's3',
      brandId: 'dreams_inc',
      ipId: 'smiski',
      figures: const [
        ShelfFigure(
          id: 'c',
          seriesId: 's3',
          name: 'C',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'c2',
          seriesId: 's3',
          name: 'C2',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [s1, s2, s3],
      figureStates: {'a': _owned('a'), 'b': _owned('b'), 'c': _owned('c')},
    );
    // Journey memory is no longer an Identity input (resolver 2.0).
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 5, 29),
    );
    expect(identity.archetypeId, isNot(CollectorTypeArchetypeId.curator));
  });

  test('curator can win when current shelf has IP diversity', () {
    // ≥3 IPs + average Regular Completion ≥ 50% (6.0 investment gate).
    final series = [
      _seriesWithFigures(
        id: 's1',
        brandId: 'pop_mart',
        ipId: 'the_monsters',
        catalogTemplateId: 'series_1',
        figures: const [
          ShelfFigure(
            id: 'a1',
            seriesId: 's1',
            name: 'A1',
            rarity: 'Regular',
            isSecret: false,
          ),
          ShelfFigure(
            id: 'a2',
            seriesId: 's1',
            name: 'A2',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
      ),
      _seriesWithFigures(
        id: 's2',
        brandId: 'toptoy',
        ipId: 'hirono',
        catalogTemplateId: 'series_2',
        figures: const [
          ShelfFigure(
            id: 'b1',
            seriesId: 's2',
            name: 'B1',
            rarity: 'Regular',
            isSecret: false,
          ),
          ShelfFigure(
            id: 'b2',
            seriesId: 's2',
            name: 'B2',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
      ),
      _seriesWithFigures(
        id: 's3',
        brandId: 'sonny',
        ipId: 'sonny_angel',
        catalogTemplateId: 'series_3',
        figures: const [
          ShelfFigure(
            id: 'c1',
            seriesId: 's3',
            name: 'C1',
            rarity: 'Regular',
            isSecret: false,
          ),
          ShelfFigure(
            id: 'c2',
            seriesId: 's3',
            name: 'C2',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
      ),
    ];
    final snap = CollectionSnapshot(
      shelfSeries: series,
      figureStates: {
        for (final s in series) s.figures.first.id: _owned(s.figures.first.id),
      },
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 5, 29),
    );
    expect(identity.archetypeId, CollectorTypeArchetypeId.curator);
  });

  test('trend does not win from two recent on a mostly-old shelf', () {
    final catalog = CatalogSeedBundle(
      brands: const [],
      ips: const [],
      series: [
        for (var i = 0; i < 8; i++)
          seed.CatalogSeries(
            id: 'old_$i',
            brandId: 'pop_mart',
            ipId: 'ip_$i',
            displayName: 'Old $i',
            releaseDate: '2024-01-0${(i % 9) + 1}',
            isBlindBox: true,
            imageKey: 'old_$i',
          ),
        seed.CatalogSeries(
          id: 'recent_a',
          brandId: 'pop_mart',
          ipId: 'ip_r1',
          displayName: 'Recent A',
          releaseDate: '2026-03-01',
          isBlindBox: true,
          imageKey: 'recent_a',
        ),
        seed.CatalogSeries(
          id: 'recent_b',
          brandId: 'toptoy',
          ipId: 'ip_r2',
          displayName: 'Recent B',
          releaseDate: '2026-02-15',
          isBlindBox: true,
          imageKey: 'recent_b',
        ),
      ],
      figures: const [],
    );
    final series = <ShelfSeries>[
      for (var i = 0; i < 8; i++)
        _seriesWithFigures(
          id: 'old$i',
          catalogTemplateId: 'old_$i',
          brandId: i.isEven ? 'pop_mart' : 'toptoy',
          ipId: 'ip_$i',
          figures: [
            ShelfFigure(
              id: 'o$i',
              seriesId: 'old$i',
              name: 'O$i',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
        ),
      _seriesWithFigures(
        id: 'ra',
        catalogTemplateId: 'recent_a',
        brandId: 'pop_mart',
        ipId: 'ip_r1',
        figures: const [
          ShelfFigure(
            id: 'ra0',
            seriesId: 'ra',
            name: 'RA',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
      ),
      _seriesWithFigures(
        id: 'rb',
        catalogTemplateId: 'recent_b',
        brandId: 'toptoy',
        ipId: 'ip_r2',
        figures: const [
          ShelfFigure(
            id: 'rb0',
            seriesId: 'rb',
            name: 'RB',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
      ),
    ];
    final snap = CollectionSnapshot(
      shelfSeries: series,
      figureStates: {
        for (final s in series)
          for (final f in s.figures) f.id: _owned(f.id),
      },
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      catalog: catalog,
      revealedAt: DateTime(2026, 5, 1),
    );
    // recentRatio = 2/10 = 0.2 — not majority (6.0 requires > 0.50).
    expect(identity.scores[CollectorTypeArchetypeId.trendChaser], 0);
    expect(identity.archetypeId, isNot(CollectorTypeArchetypeId.trendChaser));
  });

  test('hunter requires secret hit rate, not merely two secrets present', () {
    final figures = <ShelfFigure>[
      for (var i = 0; i < 10; i++)
        ShelfFigure(
          id: 'sec$i',
          seriesId: 's1',
          name: 'Secret $i',
          rarity: 'Secret',
          isSecret: true,
        ),
    ];
    final series = _seriesWithFigures(id: 's1', figures: figures);
    final snap = CollectionSnapshot(
      shelfSeries: [series],
      // 2 owned secrets / 10 slots = 0.2 < hunter hit rate 0.50
      figureStates: {'sec0': _owned('sec0'), 'sec1': _owned('sec1')},
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 1, 1),
    );
    expect(identity.scores[CollectorTypeArchetypeId.hunter], 0);
  });

  test(
    'completionist requires finish share, not two completes on a large shelf',
    () {
      final series = [
        for (var i = 0; i < 6; i++)
          _seriesWithFigures(
            id: 's$i',
            ipId: 'ip$i',
            figures: [
              for (var j = 0; j < 4; j++)
                ShelfFigure(
                  id: 's${i}_$j',
                  seriesId: 's$i',
                  name: 'F$j',
                  rarity: 'Regular',
                  isSecret: false,
                ),
            ],
          ),
      ];
      // Two series fully complete; four barely started → finishRatio = 2/6 < 0.60
      final states = <String, TrackedFigure>{
        for (final f in series[0].figures) f.id: _owned(f.id),
        for (final f in series[1].figures) f.id: _owned(f.id),
        series[2].figures.first.id: _owned(series[2].figures.first.id),
        series[3].figures.first.id: _owned(series[3].figures.first.id),
        series[4].figures.first.id: _owned(series[4].figures.first.id),
        series[5].figures.first.id: _owned(series[5].figures.first.id),
      };
      final snap = CollectionSnapshot(
        shelfSeries: series,
        figureStates: states,
      );
      final identity = resolveCollectorType(
        snapshot: snap,
        profile: interpretShelf(snap),
        revealedAt: DateTime(2026, 7, 1),
      );
      expect(identity.scores[CollectorTypeArchetypeId.completionist], 0);
    },
  );

  test('loyalist-dominant shelf does not score curator from IP presence', () {
    final s1 = _seriesWithFigures(
      id: 's1',
      brandId: 'dreams_inc',
      ipId: 'smiski',
      figures: const [
        ShelfFigure(
          id: 'a',
          seriesId: 's1',
          name: 'A',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'a2',
          seriesId: 's1',
          name: 'A2',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final s2 = _seriesWithFigures(
      id: 's2',
      brandId: 'dreams_inc',
      ipId: 'smiski',
      figures: const [
        ShelfFigure(
          id: 'b',
          seriesId: 's2',
          name: 'B',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'b2',
          seriesId: 's2',
          name: 'B2',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final s3 = _seriesWithFigures(
      id: 's3',
      brandId: 'pop_mart',
      ipId: 'hirono',
      figures: const [
        ShelfFigure(
          id: 'c',
          seriesId: 's3',
          name: 'C',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'c2',
          seriesId: 's3',
          name: 'C2',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [s1, s2, s3],
      figureStates: {'a': _owned('a'), 'b': _owned('b'), 'c': _owned('c')},
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 5, 29),
    );
    // Smiski share 2/3 — Loyalist defines; Curator must not also score.
    expect(identity.archetypeId, CollectorTypeArchetypeId.loyalist);
    expect(identity.scores[CollectorTypeArchetypeId.curator], 0);
  });

  test('Smiski-only shelf now resolves to loyalist', () {
    final s1 = _seriesWithFigures(
      id: 's1',
      brandId: 'dreams_inc',
      ipId: 'smiski',
      figures: const [
        ShelfFigure(
          id: 'a',
          seriesId: 's1',
          name: 'A',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'a2',
          seriesId: 's1',
          name: 'A2',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final s2 = _seriesWithFigures(
      id: 's2',
      brandId: 'dreams_inc',
      ipId: 'smiski',
      figures: const [
        ShelfFigure(
          id: 'b',
          seriesId: 's2',
          name: 'B',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'b2',
          seriesId: 's2',
          name: 'B2',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final s3 = _seriesWithFigures(
      id: 's3',
      brandId: 'dreams_inc',
      ipId: 'smiski',
      figures: const [
        ShelfFigure(
          id: 'c',
          seriesId: 's3',
          name: 'C',
          rarity: 'Regular',
          isSecret: false,
        ),
        ShelfFigure(
          id: 'c2',
          seriesId: 's3',
          name: 'C2',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [s1, s2, s3],
      figureStates: {'a': _owned('a'), 'b': _owned('b'), 'c': _owned('c')},
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 5, 29),
    );
    expect(identity.archetypeId, CollectorTypeArchetypeId.loyalist);
  });

  test('curator score reflects shelfIpSpread not Journey depth', () {
    final series = [
      for (final e in [
        ('s1', 'pop_mart', 'the_monsters'),
        ('s2', 'toptoy', 'hirono'),
        ('s3', 'sonny', 'sonny_angel'),
      ])
        ShelfSeries(
          id: e.$1,
          name: 'Series ${e.$1}',
          brand: e.$2,
          ipName: e.$3,
          figures: [
            ShelfFigure(
              id: '${e.$1}_a',
              seriesId: e.$1,
              name: 'A',
              rarity: 'Regular',
              isSecret: false,
            ),
            ShelfFigure(
              id: '${e.$1}_b',
              seriesId: e.$1,
              name: 'B',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
          shelfAccent: const Color(0xFFE4F2EA),
          taxonomyBrandId: e.$2,
          taxonomyIpId: e.$3,
          catalogTemplateId: 'series_${e.$1}',
        ),
    ];
    final snap = CollectionSnapshot(
      shelfSeries: series,
      figureStates: {
        for (final s in series) s.figures.first.id: _owned(s.figures.first.id),
      },
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 5, 29),
    );
    // 3 IPs, avg Regular 50% → 28 + 3*4 + 0.5*22 = 51
    expect(identity.scores[CollectorTypeArchetypeId.curator], 51);
  });

  test(
    'worldbuilder is authorship — mostly custom without notes still scores',
    () {
      final customs = [
        for (var i = 0; i < 2; i++)
          _seriesWithFigures(
            id: 'c$i',
            customLocal: true,
            ipId: 'custom_ip_$i',
            brandId: 'indie_$i',
            figures: [
              ShelfFigure(
                id: 'c${i}_a',
                seriesId: 'c$i',
                name: 'A',
                rarity: 'Regular',
                isSecret: false,
              ),
              ShelfFigure(
                id: 'c${i}_b',
                seriesId: 'c$i',
                name: 'B',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
      ];
      final snap = CollectionSnapshot(
        shelfSeries: customs,
        figureStates: const {},
      );
      expect(customs.every((s) => s.isCustomLocal), isTrue);
      final identity = resolveCollectorType(
        snapshot: snap,
        profile: interpretShelf(snap),
        revealedAt: DateTime(2026, 7, 1),
      );
      // ratio=1, series=2, figures=4 → 36 + 40 + 10 + 4 = 90
      expect(identity.scores[CollectorTypeArchetypeId.worldbuilder], 90);
      expect(identity.archetypeId, CollectorTypeArchetypeId.worldbuilder);
    },
  );

  test('catalog-only shelf never scores worldbuilder', () {
    final series = _seriesWithFigures(
      id: 's1',
      catalogTemplateId: 'official_1',
      figures: const [
        ShelfFigure(
          id: 'a',
          seriesId: 's1',
          name: 'A',
          rarity: 'Regular',
          isSecret: false,
        ),
      ],
    );
    final snap = CollectionSnapshot(
      shelfSeries: [series],
      figureStates: {'a': _owned('a')},
    );
    final identity = resolveCollectorType(
      snapshot: snap,
      profile: interpretShelf(snap),
      revealedAt: DateTime(2026, 7, 1),
    );
    expect(identity.scores[CollectorTypeArchetypeId.worldbuilder], 0);
  });

  test(
    'sparse custom mix below authorship gate does not score worldbuilder',
    () {
      final custom = ShelfSeries(
        id: 'c1',
        name: 'Custom',
        brand: 'Independent',
        ipName: 'Mine',
        figures: const [
          ShelfFigure(
            id: 'c',
            seriesId: 'c1',
            name: 'C',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
        shelfAccent: const Color(0xFFE4F2EA),
        notes: 'lore',
      );
      final catalog = [
        for (var i = 0; i < 4; i++)
          _seriesWithFigures(
            id: 'cat$i',
            catalogTemplateId: 'official_$i',
            brandId: 'pop_mart',
            ipId: 'ip$i',
            figures: [
              ShelfFigure(
                id: 'f$i',
                seriesId: 'cat$i',
                name: 'F$i',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
          ),
      ];
      final snap = CollectionSnapshot(
        shelfSeries: [custom, ...catalog],
        figureStates: {
          'c': _owned('c'),
          for (var i = 0; i < 4; i++) 'f$i': _owned('f$i'),
        },
      );
      // customRatio = 0.2 < 0.3 gate
      final identity = resolveCollectorType(
        snapshot: snap,
        profile: interpretShelf(snap),
        revealedAt: DateTime(2026, 7, 1),
      );
      expect(identity.stats.customSeriesRatio, closeTo(0.2, 0.001));
      expect(identity.scores[CollectorTypeArchetypeId.worldbuilder], 0);
    },
  );

  test(
    'completionist wins master-complete multi-IP shelf (not Journey Curator)',
    () {
      final series = [
        for (final (id, ip) in [
          ('a1', 'ip1'),
          ('a2', 'ip2'),
          ('a3', 'ip3'),
          ('a4', 'ip4'),
          ('a5', 'ip5'),
        ])
          _seriesWithFigures(
            id: id,
            brandId: 'pop_mart',
            ipId: ip,
            figures: [
              for (var i = 0; i < 3; i++)
                ShelfFigure(
                  id: '${id}_$i',
                  seriesId: id,
                  name: 'F$i',
                  rarity: 'Regular',
                  isSecret: false,
                ),
            ],
          ),
      ];
      final states = <String, TrackedFigure>{
        for (final s in series.take(3))
          for (final f in s.figures) f.id: _owned(f.id),
      };
      final snap = CollectionSnapshot(
        shelfSeries: series,
        figureStates: states,
      );
      final identity = resolveCollectorType(
        snapshot: snap,
        profile: interpretShelf(snap),
        revealedAt: DateTime(2026, 7, 1),
      );
      expect(identity.archetypeId, CollectorTypeArchetypeId.completionist);
      expect(
        identity.scores[CollectorTypeArchetypeId.completionist]! >
            identity.scores[CollectorTypeArchetypeId.curator]!,
        isTrue,
      );
    },
  );
}
