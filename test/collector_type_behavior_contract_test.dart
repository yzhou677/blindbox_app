import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as seed;
import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TrackedFigure _owned(String id) =>
    TrackedFigure(figureId: id, state: FigureCollectionState.owned);

TrackedFigure _wish(String id) =>
    TrackedFigure(figureId: id, state: FigureCollectionState.wishlist);

ShelfFigure _reg(String id, String seriesId) => ShelfFigure(
      id: id,
      seriesId: seriesId,
      name: id,
      rarity: 'Regular',
      isSecret: false,
    );

ShelfFigure _sec(String id, String seriesId) => ShelfFigure(
      id: id,
      seriesId: seriesId,
      name: id,
      rarity: 'Secret',
      isSecret: true,
    );

ShelfSeries _series({
  required String id,
  required String ipId,
  required List<ShelfFigure> figures,
  String brandId = 'pop_mart',
  String? catalogTemplateId,
  bool custom = false,
  String? notes,
  String? cover,
}) {
  return ShelfSeries(
    id: id,
    name: 'Series $id',
    brand: 'Brand',
    ipName: ipId,
    figures: figures,
    shelfAccent: const Color(0xFFE4F2EA),
    taxonomyBrandId: brandId,
    taxonomyIpId: ipId,
    catalogTemplateId: custom ? null : (catalogTemplateId ?? 'cat_$id'),
    notes: custom ? notes : null,
    customCoverImageUri: custom ? cover : null,
  );
}

CollectorTypeArchetypeId _resolve(
  CollectionSnapshot snap, {
  CatalogSeedBundle? catalog,
  DateTime? now,
}) {
  return resolveCollectorType(
    snapshot: snap,
    profile: interpretShelf(snap),
    catalog: catalog,
    revealedAt: now ?? DateTime(2026, 6, 1),
  ).archetypeId;
}

CollectionSnapshot _snap(
  List<ShelfSeries> series,
  Map<String, TrackedFigure> states,
) =>
    CollectionSnapshot(shelfSeries: series, figureStates: states);

/// Regular-complete series: 2 regulars both owned.
ShelfSeries _completeSeries(String id, String ip) {
  final figs = [_reg('${id}_a', id), _reg('${id}_b', id)];
  return _series(id: id, ipId: ip, figures: figs);
}

Map<String, TrackedFigure> _ownAll(ShelfSeries s) => {
      for (final f in s.figures) f.id: _owned(f.id),
    };

/// Near-complete: 2 of 2 progress would be complete; use 6/7 regulars ≈ 85.7%.
ShelfSeries _nearSeries(String id, String ip) {
  final figs = [
    for (var i = 0; i < 7; i++) _reg('${id}_r$i', id),
  ];
  return _series(id: id, ipId: ip, figures: figs);
}

Map<String, TrackedFigure> _ownNear(ShelfSeries s) => {
      for (var i = 0; i < 6; i++) s.figures[i].id: _owned(s.figures[i].id),
    };

void main() {
  group('Completionist 6.0', () {
    test('1 of 1 completed → not Completionist', () {
      final s = _completeSeries('s1', 'ip_a');
      expect(
        _resolve(_snap([s], _ownAll(s))),
        isNot(CollectorTypeArchetypeId.completionist),
      );
    });

    test('2 of 3 completed → qualifies', () {
      final a = _completeSeries('a', 'ip_a');
      final b = _completeSeries('b', 'ip_b');
      final c = _completeSeries('c', 'ip_c');
      final states = {..._ownAll(a), ..._ownAll(b)};
      expect(
        _resolve(_snap([a, b, c], states)),
        CollectorTypeArchetypeId.completionist,
      );
    });

    test('2 of 4 completed → does not qualify at 50%', () {
      final series = [
        for (var i = 0; i < 4; i++) _completeSeries('s$i', 'ip_$i'),
      ];
      final states = {
        ..._ownAll(series[0]),
        ..._ownAll(series[1]),
      };
      final id = _resolve(_snap(series, states));
      expect(id, isNot(CollectorTypeArchetypeId.completionist));
    });

    test('3 of 5 completed → qualifies at 60%', () {
      final series = [
        for (var i = 0; i < 5; i++) _completeSeries('s$i', 'ip_$i'),
      ];
      final states = {
        ..._ownAll(series[0]),
        ..._ownAll(series[1]),
        ..._ownAll(series[2]),
      };
      expect(
        _resolve(_snap(series, states)),
        CollectorTypeArchetypeId.completionist,
      );
    });

    test('near path: 3 of 5 near-complete → qualifies', () {
      final series = [
        for (var i = 0; i < 5; i++) _nearSeries('n$i', 'ip_$i'),
      ];
      final states = {
        ..._ownNear(series[0]),
        ..._ownNear(series[1]),
        ..._ownNear(series[2]),
      };
      expect(
        _resolve(_snap(series, states)),
        CollectorTypeArchetypeId.completionist,
      );
    });

    test('near path below 60% → does not qualify', () {
      final series = [
        for (var i = 0; i < 5; i++) _nearSeries('n$i', 'ip_$i'),
      ];
      final states = {
        ..._ownNear(series[0]),
        ..._ownNear(series[1]),
      };
      expect(
        _resolve(_snap(series, states)),
        isNot(CollectorTypeArchetypeId.completionist),
      );
    });
  });

  group('Hunter / Lucky One 6.0', () {
    test('1 Secret on small shelf at 50% → Lucky One', () {
      final s = _series(
        id: 's1',
        ipId: 'ip_a',
        figures: [_reg('r', 's1'), _sec('sec', 's1')],
      );
      expect(
        _resolve(_snap([s], {'sec': _owned('sec')})),
        CollectorTypeArchetypeId.luckyOne,
      );
    });

    test('2 Secrets at 50% hit rate → Hunter', () {
      final s = _series(
        id: 's1',
        ipId: 'ip_a',
        figures: [
          _reg('r', 's1'),
          _sec('s1', 's1'),
          _sec('s2', 's1'),
          _sec('s3', 's1'),
          _sec('s4', 's1'),
        ],
      );
      expect(
        _resolve(_snap([s], {'s1': _owned('s1'), 's2': _owned('s2')})),
        CollectorTypeArchetypeId.hunter,
      );
    });

    test('Hunter eligible → Lucky One score is zero', () {
      final s = _series(
        id: 's1',
        ipId: 'ip_a',
        figures: [_sec('a', 's1'), _sec('b', 's1')],
      );
      final r = resolveCollectorType(
        snapshot: _snap([s], {'a': _owned('a'), 'b': _owned('b')}),
        profile: interpretShelf(_snap([s], {'a': _owned('a'), 'b': _owned('b')})),
        revealedAt: DateTime(2026, 6, 1),
      );
      expect(r.archetypeId, CollectorTypeArchetypeId.hunter);
      expect(r.scores[CollectorTypeArchetypeId.luckyOne], 0);
    });

    test('2 Secrets but hit rate below 50% → not Hunter', () {
      final s = _series(
        id: 's1',
        ipId: 'ip_a',
        figures: [
          _sec('a', 's1'),
          _sec('b', 's1'),
          _sec('c', 's1'),
          _sec('d', 's1'),
          _sec('e', 's1'),
        ],
      );
      // 2/5 = 40%
      expect(
        _resolve(_snap([s], {'a': _owned('a'), 'b': _owned('b')})),
        isNot(CollectorTypeArchetypeId.hunter),
      );
    });

    test('Secret hit rate uses Secret slots, not all figures', () {
      final s = _series(
        id: 's1',
        ipId: 'ip_a',
        figures: [
          for (var i = 0; i < 10; i++) _reg('r$i', 's1'),
          _sec('a', 's1'),
          _sec('b', 's1'),
        ],
      );
      // 2/2 secrets = 100% even with many regulars
      expect(
        _resolve(_snap([s], {'a': _owned('a'), 'b': _owned('b')})),
        CollectorTypeArchetypeId.hunter,
      );
    });

    test('large shelf may still qualify as Hunter', () {
      final series = <ShelfSeries>[
        for (var i = 0; i < 6; i++)
          _series(
            id: 's$i',
            ipId: 'ip_$i',
            figures: [_reg('r$i', 's$i'), _sec('sec$i', 's$i')],
          ),
      ];
      final states = {
        'sec0': _owned('sec0'),
        'sec1': _owned('sec1'),
        'sec2': _owned('sec2'),
      };
      // 3/6 = 50% secrets
      expect(_resolve(_snap(series, states)), CollectorTypeArchetypeId.hunter);
    });

    test('5+ series cannot qualify as Lucky One', () {
      final series = <ShelfSeries>[
        for (var i = 0; i < 5; i++)
          _series(
            id: 's$i',
            ipId: 'ip_$i',
            figures: [_reg('r$i', 's$i'), _sec('sec$i', 's$i')],
          ),
      ];
      // 1/5 secrets — would be Lucky if series<=4, but 5 series blocks it;
      // also not Hunter (need >=2 secrets at >=50% → 1/5 fails).
      expect(
        _resolve(_snap(series, {'sec0': _owned('sec0')})),
        isNot(CollectorTypeArchetypeId.luckyOne),
      );
    });
  });

  group('Loyalist / Curator 6.0', () {
    test('same brand, many IPs → not Loyalist', () {
      final series = [
        for (var i = 0; i < 5; i++)
          _series(
            id: 's$i',
            ipId: 'ip_$i',
            brandId: 'pop_mart',
            figures: [_reg('r$i', 's$i'), _reg('r${i}b', 's$i')],
          ),
      ];
      // Own half of each so avg completion ~50% for Curator
      final states = <String, TrackedFigure>{
        for (final s in series) s.figures.first.id: _owned(s.figures.first.id),
      };
      final id = _resolve(_snap(series, states));
      expect(id, isNot(CollectorTypeArchetypeId.loyalist));
      expect(id, CollectorTypeArchetypeId.curator);
    });

    test('3 of 5 series in one IP → Loyalist', () {
      final series = [
        for (var i = 0; i < 3; i++)
          _series(id: 'd$i', ipId: 'dimoo', figures: [_reg('d${i}a', 'd$i')]),
        _series(id: 'm0', ipId: 'molly', figures: [_reg('m0a', 'm0')]),
        _series(id: 'h0', ipId: 'hirono', figures: [_reg('h0a', 'h0')]),
      ];
      expect(
        _resolve(_snap(series, {})),
        CollectorTypeArchetypeId.loyalist,
      );
    });

    test('dominant IP below 60% → not Loyalist', () {
      final series = [
        _series(id: 'a', ipId: 'dimoo', figures: [_reg('a1', 'a')]),
        _series(id: 'b', ipId: 'dimoo', figures: [_reg('b1', 'b')]),
        _series(id: 'c', ipId: 'molly', figures: [_reg('c1', 'c')]),
        _series(id: 'd', ipId: 'hirono', figures: [_reg('d1', 'd')]),
        _series(id: 'e', ipId: 'skull', figures: [_reg('e1', 'e')]),
      ];
      // 2/5 = 40%
      expect(
        _resolve(_snap(series, {})),
        isNot(CollectorTypeArchetypeId.loyalist),
      );
    });

    test('3 IPs with avg Regular Completion >=50% → Curator', () {
      final series = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 's$i',
            ipId: 'ip_$i',
            figures: [_reg('a$i', 's$i'), _reg('b$i', 's$i')],
          ),
      ];
      final states = {
        for (final s in series) s.figures.first.id: _owned(s.figures.first.id),
      };
      final r = resolveCollectorType(
        snapshot: _snap(series, states),
        profile: interpretShelf(_snap(series, states)),
        revealedAt: DateTime(2026, 6, 1),
      );
      expect(r.archetypeId, CollectorTypeArchetypeId.curator);
      expect(r.scores[CollectorTypeArchetypeId.loyalist], 0);
    });

    test('3 IPs with shallow completion <50% → not Curator', () {
      final series = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 's$i',
            ipId: 'ip_$i',
            figures: [
              for (var j = 0; j < 4; j++) _reg('s${i}_$j', 's$i'),
            ],
          ),
      ];
      // 0 owned → avg 0
      expect(_resolve(_snap(series, {})), CollectorTypeArchetypeId.wanderer);
    });

    test('Loyalist eligible → Curator score is zero', () {
      // Multi-figure rows so partial ownership avoids Completionist.
      final series = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 'd$i',
            ipId: 'dimoo',
            figures: [_reg('x${i}a', 'd$i'), _reg('x${i}b', 'd$i')],
          ),
        _series(
          id: 'o',
          ipId: 'other',
          figures: [_reg('o1', 'o'), _reg('o2', 'o')],
        ),
      ];
      // 3/4 = 75% Dimoo; own one figure each (50% avg — not Completionist).
      final states = {
        for (final s in series) s.figures.first.id: _owned(s.figures.first.id),
      };
      final r = resolveCollectorType(
        snapshot: _snap(series, states),
        profile: interpretShelf(_snap(series, states)),
        revealedAt: DateTime(2026, 6, 1),
      );
      expect(r.archetypeId, CollectorTypeArchetypeId.loyalist);
      expect(r.scores[CollectorTypeArchetypeId.curator], 0);
    });
  });

  group('Wanderer 6.0', () {
    test('empty shelf → Wanderer', () {
      expect(
        _resolve(CollectionSnapshot.emptyTest()),
        CollectorTypeArchetypeId.wanderer,
      );
    });

    test('one ordinary series → Wanderer', () {
      final s = _series(id: 's', ipId: 'ip', figures: [_reg('r', 's')]);
      expect(_resolve(_snap([s], {})), CollectorTypeArchetypeId.wanderer);
    });

    test('specialized eligible type beats fallback Wanderer', () {
      final series = [
        for (var i = 0; i < 3; i++)
          _series(id: 'd$i', ipId: 'dimoo', figures: [_reg('x$i', 'd$i')]),
      ];
      expect(
        _resolve(_snap(series, {})),
        CollectorTypeArchetypeId.loyalist,
      );
    });
  });

  group('Minimalist 6.0', () {
    test('3 series at 70% → qualifies', () {
      final series = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 's$i',
            ipId: 'ip_$i',
            figures: [
              for (var j = 0; j < 10; j++) _reg('s${i}_$j', 's$i'),
            ],
          ),
      ];
      // 7/10 each → 70%
      final states = <String, TrackedFigure>{};
      for (final s in series) {
        for (var j = 0; j < 7; j++) {
          states[s.figures[j].id] = _owned(s.figures[j].id);
        }
      }
      expect(_resolve(_snap(series, states)), CollectorTypeArchetypeId.minimalist);
    });

    test('4 series at 100% → not Minimalist', () {
      final series = [
        for (var i = 0; i < 4; i++) _completeSeries('s$i', 'ip_$i'),
      ];
      final states = {
        for (final s in series) ..._ownAll(s),
      };
      expect(
        _resolve(_snap(series, states)),
        isNot(CollectorTypeArchetypeId.minimalist),
      );
    });

    test('3 series below 70% → does not qualify', () {
      final series = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 's$i',
            ipId: 'ip_$i',
            figures: [
              for (var j = 0; j < 10; j++) _reg('s${i}_$j', 's$i'),
            ],
          ),
      ];
      final states = <String, TrackedFigure>{};
      for (final s in series) {
        for (var j = 0; j < 5; j++) {
          states[s.figures[j].id] = _owned(s.figures[j].id);
        }
      }
      expect(
        _resolve(_snap(series, states)),
        isNot(CollectorTypeArchetypeId.minimalist),
      );
    });

    test('more than 12 owned figures does not disqualify Minimalist', () {
      final series = [
        for (var i = 0; i < 2; i++)
          _series(
            id: 's$i',
            ipId: 'ip_$i',
            figures: [
              for (var j = 0; j < 10; j++) _reg('s${i}_$j', 's$i'),
            ],
          ),
      ];
      // 7/10 each → 70%, 20 figures owned, not fully complete
      final states = <String, TrackedFigure>{};
      for (final s in series) {
        for (var j = 0; j < 7; j++) {
          states[s.figures[j].id] = _owned(s.figures[j].id);
        }
      }
      expect(_resolve(_snap(series, states)), CollectorTypeArchetypeId.minimalist);
    });
  });

  group('Worldbuilder 6.0', () {
    test('1 custom of 1 → not Worldbuilder', () {
      final s = _series(
        id: 'c1',
        ipId: 'custom_ip',
        custom: true,
        figures: [_reg('r', 'c1')],
      );
      expect(
        _resolve(_snap([s], {})),
        isNot(CollectorTypeArchetypeId.worldbuilder),
      );
    });

    test('2 custom of 3 → qualifies', () {
      final customs = [
        for (var i = 0; i < 2; i++)
          _series(
            id: 'c$i',
            ipId: 'cust_$i',
            custom: true,
            notes: 'note',
            figures: [_reg('r$i', 'c$i')],
          ),
      ];
      final catalog = _series(
        id: 'cat',
        ipId: 'labubu',
        figures: [_reg('cr', 'cat')],
      );
      expect(
        _resolve(_snap([...customs, catalog], {})),
        CollectorTypeArchetypeId.worldbuilder,
      );
    });

    test('2 custom of 4 → does not qualify at exactly 50%', () {
      final customs = [
        for (var i = 0; i < 2; i++)
          _series(
            id: 'c$i',
            ipId: 'cust_$i',
            custom: true,
            figures: [_reg('r$i', 'c$i')],
          ),
      ];
      final cats = [
        for (var i = 0; i < 2; i++)
          _series(id: 'k$i', ipId: 'ip_$i', figures: [_reg('kr$i', 'k$i')]),
      ];
      expect(
        _resolve(_snap([...customs, ...cats], {})),
        isNot(CollectorTypeArchetypeId.worldbuilder),
      );
    });
  });

  group('Dreamer 6.0', () {
    test('2 wishlist, 1 owned → qualifies', () {
      final s = _series(
        id: 's',
        ipId: 'ip',
        figures: [_reg('o', 's'), _reg('w1', 's'), _reg('w2', 's')],
      );
      expect(
        _resolve(_snap([s], {
          'o': _owned('o'),
          'w1': _wish('w1'),
          'w2': _wish('w2'),
        })),
        CollectorTypeArchetypeId.dreamer,
      );
    });

    test('wishlist ratio exactly 50% → does not qualify', () {
      final s = _series(
        id: 's',
        ipId: 'ip',
        figures: [_reg('o1', 's'), _reg('o2', 's'), _reg('w1', 's'), _reg('w2', 's')],
      );
      expect(
        _resolve(_snap([s], {
          'o1': _owned('o1'),
          'o2': _owned('o2'),
          'w1': _wish('w1'),
          'w2': _wish('w2'),
        })),
        isNot(CollectorTypeArchetypeId.dreamer),
      );
    });

    test('only 1 wishlist → does not qualify', () {
      final s = _series(
        id: 's',
        ipId: 'ip',
        figures: [_reg('w1', 's')],
      );
      expect(
        _resolve(_snap([s], {'w1': _wish('w1')})),
        isNot(CollectorTypeArchetypeId.dreamer),
      );
    });
  });

  group('Trend Chaser 6.0', () {
    CatalogSeedBundle catalogWithDates(Map<String, String> idToDate) {
      return CatalogSeedBundle(
        brands: const [],
        ips: const [],
        series: [
          for (final e in idToDate.entries)
            seed.CatalogSeries(
              id: e.key,
              brandId: 'pop_mart',
              ipId: 'ip',
              displayName: e.key,
              releaseDate: e.value,
              isBlindBox: true,
              imageKey: e.key,
            ),
        ],
        figures: const [],
      );
    }

    test('2 of 3 within 90 days → qualifies', () {
      final now = DateTime(2026, 6, 1);
      final series = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 's$i',
            ipId: 'ip_$i',
            catalogTemplateId: 'cat_$i',
            figures: [_reg('r$i', 's$i')],
          ),
      ];
      final catalog = catalogWithDates({
        'cat_0': '2026-05-01',
        'cat_1': '2026-04-15',
        'cat_2': '2025-01-01',
      });
      expect(
        _resolve(_snap(series, {}), catalog: catalog, now: now),
        CollectorTypeArchetypeId.trendChaser,
      );
    });

    test('2 of 4 recent → does not qualify at exactly 50%', () {
      final now = DateTime(2026, 6, 1);
      final series = [
        for (var i = 0; i < 4; i++)
          _series(
            id: 's$i',
            ipId: 'ip_$i',
            catalogTemplateId: 'cat_$i',
            figures: [_reg('r$i', 's$i')],
          ),
      ];
      final catalog = catalogWithDates({
        'cat_0': '2026-05-01',
        'cat_1': '2026-04-15',
        'cat_2': '2025-01-01',
        'cat_3': '2024-01-01',
      });
      expect(
        _resolve(_snap(series, {}), catalog: catalog, now: now),
        isNot(CollectorTypeArchetypeId.trendChaser),
      );
    });

    test('91–180 days ago → not recent', () {
      final now = DateTime(2026, 6, 1);
      final series = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 's$i',
            ipId: 'ip_$i',
            catalogTemplateId: 'cat_$i',
            figures: [_reg('r$i', 's$i')],
          ),
      ];
      final catalog = catalogWithDates({
        'cat_0': '2026-02-01', // ~120 days
        'cat_1': '2026-01-15',
        'cat_2': '2026-01-01',
      });
      expect(
        _resolve(_snap(series, {}), catalog: catalog, now: now),
        isNot(CollectorTypeArchetypeId.trendChaser),
      );
    });

    test('one recent series → does not qualify', () {
      final now = DateTime(2026, 6, 1);
      final series = [
        _series(
          id: 's0',
          ipId: 'ip_0',
          catalogTemplateId: 'cat_0',
          figures: [_reg('r0', 's0')],
        ),
        _series(
          id: 's1',
          ipId: 'ip_1',
          catalogTemplateId: 'cat_1',
          figures: [_reg('r1', 's1')],
        ),
      ];
      final catalog = catalogWithDates({
        'cat_0': '2026-05-01',
        'cat_1': '2024-01-01',
      });
      expect(
        _resolve(_snap(series, {}), catalog: catalog, now: now),
        isNot(CollectorTypeArchetypeId.trendChaser),
      );
    });

    test('recency aging changes signature', () {
      final series = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 's$i',
            ipId: 'ip_$i',
            catalogTemplateId: 'cat_$i',
            figures: [_reg('r$i', 's$i')],
          ),
      ];
      final catalog = catalogWithDates({
        'cat_0': '2026-05-01',
        'cat_1': '2026-04-20',
        'cat_2': '2026-04-10',
      });
      final snap = _snap(series, {});
      final young = computeCollectorTypeSignatureHash(
        snap,
        catalog: catalog,
        now: DateTime(2026, 6, 1),
      );
      final aged = computeCollectorTypeSignatureHash(
        snap,
        catalog: catalog,
        now: DateTime(2026, 10, 1),
      );
      expect(young, isNot(aged));
      expect(
        _resolve(snap, catalog: catalog, now: DateTime(2026, 10, 1)),
        isNot(CollectorTypeArchetypeId.trendChaser),
      );
    });
  });

  group('Whole-board winners 6.0', () {
    test('small lucky shelf → Lucky One', () {
      final s = _series(
        id: 'l',
        ipId: 'ip',
        figures: [_reg('r', 'l'), _sec('s', 'l')],
      );
      expect(
        _resolve(_snap([s], {'s': _owned('s')})),
        CollectorTypeArchetypeId.luckyOne,
      );
    });

    test('mature Secret pursuit → Hunter', () {
      final series = [
        for (var i = 0; i < 5; i++)
          _series(
            id: 'h$i',
            ipId: 'ip_$i',
            figures: [_reg('r$i', 'h$i'), _sec('s$i', 'h$i')],
          ),
      ];
      final states = {
        for (var i = 0; i < 3; i++) 's$i': _owned('s$i'),
      };
      expect(
        _resolve(_snap(series, states)),
        CollectorTypeArchetypeId.hunter,
      );
    });

    test('one-IP-dominant shelf → Loyalist', () {
      final series = [
        for (var i = 0; i < 3; i++)
          _series(id: 'd$i', ipId: 'dimoo', figures: [_reg('x$i', 'd$i')]),
      ];
      expect(_resolve(_snap(series, {})), CollectorTypeArchetypeId.loyalist);
    });

    test('same-brand multi-IP invested shelf → Curator, not Loyalist', () {
      final series = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 'c$i',
            ipId: 'ip_$i',
            brandId: 'pop_mart',
            figures: [_reg('a$i', 'c$i'), _reg('b$i', 'c$i')],
          ),
      ];
      final states = {
        for (final s in series) s.figures.first.id: _owned(s.figures.first.id),
      };
      expect(
        _resolve(_snap(series, states)),
        CollectorTypeArchetypeId.curator,
      );
    });

    test('broad but shallow / undefined shelf → Wanderer', () {
      final series = [
        for (var i = 0; i < 4; i++)
          _series(
            id: 'w$i',
            ipId: 'ip_$i',
            figures: [
              for (var j = 0; j < 10; j++) _reg('w${i}_$j', 'w$i'),
            ],
          ),
      ];
      // Own 2/10 each → 20% avg, no dominance
      final states = <String, TrackedFigure>{};
      for (final s in series) {
        states[s.figures[0].id] = _owned(s.figures[0].id);
        states[s.figures[1].id] = _owned(s.figures[1].id);
      }
      expect(_resolve(_snap(series, states)), CollectorTypeArchetypeId.wanderer);
    });

    test('small polished shelf → Minimalist', () {
      final series = [
        for (var i = 0; i < 2; i++)
          _series(
            id: 'm$i',
            ipId: 'ip_$i',
            figures: [
              for (var j = 0; j < 10; j++) _reg('m${i}_$j', 'm$i'),
            ],
          ),
      ];
      final states = <String, TrackedFigure>{};
      for (final s in series) {
        for (var j = 0; j < 7; j++) {
          states[s.figures[j].id] = _owned(s.figures[j].id);
        }
      }
      expect(
        _resolve(_snap(series, states)),
        CollectorTypeArchetypeId.minimalist,
      );
    });

    test('custom-dominant authored shelf → Worldbuilder', () {
      final series = [
        for (var i = 0; i < 2; i++)
          _series(
            id: 'c$i',
            ipId: 'cust_$i',
            custom: true,
            figures: [_reg('r$i', 'c$i')],
          ),
      ];
      expect(
        _resolve(_snap(series, {})),
        CollectorTypeArchetypeId.worldbuilder,
      );
    });

    test('wishlist-dominant shelf → Dreamer', () {
      final s = _series(
        id: 'dr',
        ipId: 'ip_a',
        figures: [_reg('o', 'dr'), _reg('w1', 'dr'), _reg('w2', 'dr')],
      );
      expect(
        _resolve(_snap([s], {
          'o': _owned('o'),
          'w1': _wish('w1'),
          'w2': _wish('w2'),
        })),
        CollectorTypeArchetypeId.dreamer,
      );
    });

    test('recent-release-majority shelf → Trend Chaser', () {
      final now = DateTime(2026, 6, 1);
      final series = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 't$i',
            ipId: 'tip_$i',
            catalogTemplateId: 'tcat_$i',
            figures: [_reg('tr$i', 't$i')],
          ),
      ];
      final catalog = CatalogSeedBundle(
        brands: const [],
        ips: const [],
        series: [
          for (var i = 0; i < 3; i++)
            seed.CatalogSeries(
              id: 'tcat_$i',
              brandId: 'pop_mart',
              ipId: 'tip_$i',
              displayName: 't$i',
              releaseDate: '2026-05-0${i + 1}',
              isBlindBox: true,
              imageKey: 'tcat_$i',
            ),
        ],
        figures: const [],
      );
      expect(
        _resolve(_snap(series, {}), catalog: catalog, now: now),
        CollectorTypeArchetypeId.trendChaser,
      );
    });

    test('majority completed shelf → Completionist', () {
      final series = [
        for (var i = 0; i < 3; i++) _completeSeries('p$i', 'ip_$i'),
      ];
      final states = {
        ..._ownAll(series[0]),
        ..._ownAll(series[1]),
      };
      expect(
        _resolve(_snap(series, states)),
        CollectorTypeArchetypeId.completionist,
      );
    });
  });

  group('Reachability probe 6.0', () {
    test('all specialized types remain reachable', () {
      final reached = <CollectorTypeArchetypeId>{};

      // Lucky One
      final lucky = _series(
        id: 'l',
        ipId: 'ip',
        figures: [_reg('lr', 'l'), _sec('ls', 'l')],
      );
      reached.add(_resolve(_snap([lucky], {'ls': _owned('ls')})));

      // Hunter
      final hunt = _series(
        id: 'h',
        ipId: 'ip',
        figures: [_sec('ha', 'h'), _sec('hb', 'h')],
      );
      reached.add(
        _resolve(_snap([hunt], {'ha': _owned('ha'), 'hb': _owned('hb')})),
      );

      // Loyalist
      final loyal = [
        for (var i = 0; i < 3; i++)
          _series(id: 'd$i', ipId: 'dimoo', figures: [_reg('dx$i', 'd$i')]),
      ];
      reached.add(_resolve(_snap(loyal, {})));

      // Curator
      final cur = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 'c$i',
            ipId: 'ip_$i',
            figures: [_reg('ca$i', 'c$i'), _reg('cb$i', 'c$i')],
          ),
      ];
      final curStates = {
        for (final s in cur) s.figures.first.id: _owned(s.figures.first.id),
      };
      reached.add(_resolve(_snap(cur, curStates)));

      // Wanderer
      reached.add(_resolve(CollectionSnapshot.emptyTest()));

      // Minimalist — refined but not fully complete (avoids Completionist).
      final mini = [
        for (var i = 0; i < 2; i++)
          _series(
            id: 'm$i',
            ipId: 'ip_$i',
            figures: [
              for (var j = 0; j < 10; j++) _reg('m${i}_$j', 'm$i'),
            ],
          ),
      ];
      final miniStates = <String, TrackedFigure>{};
      for (final s in mini) {
        for (var j = 0; j < 7; j++) {
          miniStates[s.figures[j].id] = _owned(s.figures[j].id);
        }
      }
      reached.add(_resolve(_snap(mini, miniStates)));

      // Worldbuilder
      final wb = [
        for (var i = 0; i < 2; i++)
          _series(
            id: 'w$i',
            ipId: 'cw_$i',
            custom: true,
            figures: [_reg('wr$i', 'w$i')],
          ),
      ];
      reached.add(_resolve(_snap(wb, {})));

      // Dreamer
      final dream = _series(
        id: 'dr',
        ipId: 'ip',
        figures: [_reg('do', 'dr'), _reg('dw1', 'dr'), _reg('dw2', 'dr')],
      );
      reached.add(
        _resolve(_snap([dream], {
          'do': _owned('do'),
          'dw1': _wish('dw1'),
          'dw2': _wish('dw2'),
        })),
      );

      // Completionist
      final comp = [
        for (var i = 0; i < 3; i++) _completeSeries('p$i', 'ip_$i'),
      ];
      reached.add(
        _resolve(_snap(comp, {
          ..._ownAll(comp[0]),
          ..._ownAll(comp[1]),
        })),
      );

      // Trend
      final now = DateTime(2026, 6, 1);
      final trendSeries = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 't$i',
            ipId: 'tip_$i',
            catalogTemplateId: 'tcat_$i',
            figures: [_reg('tr$i', 't$i')],
          ),
      ];
      final trendCatalog = CatalogSeedBundle(
        brands: const [],
        ips: const [],
        series: [
          for (var i = 0; i < 3; i++)
            seed.CatalogSeries(
              id: 'tcat_$i',
              brandId: 'pop_mart',
              ipId: 'tip_$i',
              displayName: 't$i',
              releaseDate: '2026-05-0${i + 1}',
              isBlindBox: true,
              imageKey: 'tcat_$i',
            ),
        ],
        figures: const [],
      );
      reached.add(
        _resolve(
          _snap(trendSeries, {}),
          catalog: trendCatalog,
          now: now,
        ),
      );

      expect(
        reached,
        containsAll([
          CollectorTypeArchetypeId.luckyOne,
          CollectorTypeArchetypeId.hunter,
          CollectorTypeArchetypeId.loyalist,
          CollectorTypeArchetypeId.curator,
          CollectorTypeArchetypeId.wanderer,
          CollectorTypeArchetypeId.minimalist,
          CollectorTypeArchetypeId.worldbuilder,
          CollectorTypeArchetypeId.dreamer,
          CollectorTypeArchetypeId.completionist,
          CollectorTypeArchetypeId.trendChaser,
        ]),
      );
    });
  });
}
