import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as seed;
import 'package:blindbox_app/features/collection/application/shelf_emotional_interpreter.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_needs_reveal.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_resolver.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetypes.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_reveal_record.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Collector Type 6.0 full smoke matrix — explicit fixtures, no random reliance.
///
/// Scenario IDs match the product contract smoke checklist (C1…, H1…, R1…).

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
  String? figurePhoto,
}) {
  final figs = figurePhoto == null
      ? figures
      : [
          for (final f in figures)
            ShelfFigure(
              id: f.id,
              seriesId: f.seriesId,
              name: f.name,
              rarity: f.rarity,
              isSecret: f.isSecret,
              localImageUri: f.id == figures.first.id ? figurePhoto : null,
            ),
        ];
  return ShelfSeries(
    id: id,
    name: 'Series $id',
    brand: 'Brand',
    ipName: ipId,
    figures: figs,
    shelfAccent: const Color(0xFFE4F2EA),
    taxonomyBrandId: brandId,
    taxonomyIpId: custom || ipId.isEmpty ? (ipId.isEmpty ? null : ipId) : ipId,
    catalogTemplateId: custom ? null : (catalogTemplateId ?? 'cat_$id'),
    notes: custom ? notes : null,
    customCoverImageUri: custom ? cover : null,
  );
}

CollectionSnapshot _snap(
  List<ShelfSeries> series,
  Map<String, TrackedFigure> states,
) =>
    CollectionSnapshot(shelfSeries: series, figureStates: states);

dynamic _resolve(
  CollectionSnapshot snap, {
  CatalogSeedBundle? catalog,
  DateTime? now,
  bool full = false,
}) {
  final r = resolveCollectorType(
    snapshot: snap,
    profile: interpretShelf(snap),
    catalog: catalog,
    revealedAt: now ?? DateTime(2026, 6, 1),
  );
  return full ? r : r.archetypeId;
}

ShelfSeries _completeSeries(String id, String ip) {
  final figs = [_reg('${id}_a', id), _reg('${id}_b', id)];
  return _series(id: id, ipId: ip, figures: figs);
}

Map<String, TrackedFigure> _ownAll(ShelfSeries s) => {
      for (final f in s.figures) f.id: _owned(f.id),
    };

/// Own [owned] of [total] regulars for exact average completion control.
ShelfSeries _nRegs(String id, String ip, int total) => _series(
      id: id,
      ipId: ip,
      figures: [for (var i = 0; i < total; i++) _reg('${id}_$i', id)],
    );

Map<String, TrackedFigure> _ownFirst(ShelfSeries s, int n) => {
      for (var i = 0; i < n; i++) s.figures[i].id: _owned(s.figures[i].id),
    };

CatalogSeedBundle _catalog(Map<String, String> idToDate) => CatalogSeedBundle(
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

void main() {
  group('C — Completionist', () {
    test('C1 1 of 1 complete → not Completionist', () {
      final s = _completeSeries('s', 'ip');
      expect(
        _resolve(_snap([s], _ownAll(s))),
        isNot(CollectorTypeArchetypeId.completionist),
      );
    });

    test('C2 2 of 3 complete → qualifies', () {
      final series = [
        for (var i = 0; i < 3; i++) _completeSeries('s$i', 'ip_$i'),
      ];
      final states = {..._ownAll(series[0]), ..._ownAll(series[1])};
      expect(
        _resolve(_snap(series, states)),
        CollectorTypeArchetypeId.completionist,
      );
    });

    test('C3 2 of 4 complete → not at 50%', () {
      final series = [
        for (var i = 0; i < 4; i++) _completeSeries('s$i', 'ip_$i'),
      ];
      final states = {..._ownAll(series[0]), ..._ownAll(series[1])};
      expect(
        _resolve(_snap(series, states), full: true)
            .scores[CollectorTypeArchetypeId.completionist],
        0,
      );
    });

    test('C4 3 of 5 complete → qualifies at 60%', () {
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

    test('C5 near path 3 of 5 → qualifies', () {
      final near = [
        for (var i = 0; i < 3; i++) _nRegs('n$i', 'ip_$i', 7),
      ];
      final filler = [
        for (var i = 0; i < 2; i++) _nRegs('f$i', 'ip_f$i', 7),
      ];
      final states = {
        for (final s in near) ..._ownFirst(s, 6),
        for (final s in filler) ..._ownFirst(s, 1),
      };
      final r = _resolve(_snap([...near, ...filler], states), full: true);
      expect(r.scores[CollectorTypeArchetypeId.completionist], greaterThan(0));
    });

    test('C6 near 2 of 4 → does not qualify', () {
      final near = [
        for (var i = 0; i < 2; i++) _nRegs('n$i', 'ip_$i', 7),
      ];
      final filler = [
        for (var i = 0; i < 2; i++) _nRegs('f$i', 'ip_f$i', 7),
      ];
      final states = {
        for (final s in near) ..._ownFirst(s, 6),
        for (final s in filler) ..._ownFirst(s, 1),
      };
      expect(
        _resolve(_snap([...near, ...filler], states), full: true)
            .scores[CollectorTypeArchetypeId.completionist],
        0,
      );
    });
  });

  group('H / L — Hunter & Lucky One', () {
    test('H1 one Secret → not Hunter', () {
      final s = _series(
        id: 'h',
        ipId: 'ip',
        figures: [_reg('r', 'h'), _sec('s', 'h')],
      );
      expect(
        _resolve(_snap([s], {'s': _owned('s')}), full: true)
            .scores[CollectorTypeArchetypeId.hunter],
        0,
      );
    });

    test('H2 two Secrets exact 50% → Hunter', () {
      final s = _series(
        id: 'h',
        ipId: 'ip',
        figures: [_sec('a', 'h'), _sec('b', 'h'), _sec('c', 'h'), _sec('d', 'h')],
      );
      final r = _resolve(
        _snap([s], {'a': _owned('a'), 'b': _owned('b')}),
        full: true,
      );
      expect(r.scores[CollectorTypeArchetypeId.hunter], greaterThan(0));
      expect(r.archetypeId, CollectorTypeArchetypeId.hunter);
    });

    test('H3 two Secrets below 50% → not Hunter', () {
      final s = _series(
        id: 'h',
        ipId: 'ip',
        figures: [
          for (var i = 0; i < 5; i++) _sec('s$i', 'h'),
        ],
      );
      expect(
        _resolve(
          _snap([s], {'s0': _owned('s0'), 's1': _owned('s1')}),
          full: true,
        ).scores[CollectorTypeArchetypeId.hunter],
        0,
      );
    });

    test('H4 large shelf still Hunter', () {
      final series = [
        for (var i = 0; i < 8; i++)
          _series(
            id: 'h$i',
            ipId: 'ip_$i',
            figures: [_reg('r$i', 'h$i'), _sec('s$i', 'h$i')],
          ),
      ];
      // 4/8 secret slots owned = 50%
      final states = {
        for (var i = 0; i < 4; i++) 's$i': _owned('s$i'),
      };
      expect(
        _resolve(_snap(series, states)),
        CollectorTypeArchetypeId.hunter,
      );
    });

    test('H5 denominator is Secret slots not all figures', () {
      final figs = <ShelfFigure>[
        for (var i = 0; i < 16; i++) _reg('r$i', 'h'),
        for (var i = 0; i < 4; i++) _sec('s$i', 'h'),
      ];
      final s = _series(id: 'h', ipId: 'ip', figures: figs);
      final r = _resolve(
        _snap([s], {'s0': _owned('s0'), 's1': _owned('s1')}),
        full: true,
      );
      // 2/4 = 50% → Hunter; 2/20 would fail
      expect(r.stats.secretSlots, 4);
      expect(r.stats.secretOwned, 2);
      expect(r.scores[CollectorTypeArchetypeId.hunter], greaterThan(0));
    });

    test('L1 small lucky shelf → Lucky One', () {
      final series = [
        _series(
          id: 'a',
          ipId: 'ip_a',
          figures: [_reg('ar', 'a'), _sec('as', 'a')],
        ),
        _series(id: 'b', ipId: 'ip_b', figures: [_reg('br', 'b')]),
        _series(
          id: 'c',
          ipId: 'ip_c',
          figures: [_reg('cr', 'c'), _sec('cs', 'c')],
        ),
      ];
      // 1 owned of 2 secret slots
      expect(
        _resolve(_snap(series, {'as': _owned('as')})),
        CollectorTypeArchetypeId.luckyOne,
      );
    });

    test('L2 4-series boundary → Lucky One', () {
      final series = [
        for (var i = 0; i < 4; i++)
          _series(
            id: 's$i',
            ipId: 'ip_$i',
            figures: [
              _reg('r$i', 's$i'),
              if (i < 2) _sec('sec$i', 's$i'),
            ],
          ),
      ];
      expect(
        _resolve(_snap(series, {'sec0': _owned('sec0')})),
        CollectorTypeArchetypeId.luckyOne,
      );
    });

    test('L3 5-series → not Lucky One', () {
      final series = [
        for (var i = 0; i < 5; i++)
          _series(
            id: 's$i',
            ipId: 'ip_$i',
            figures: [
              _reg('r$i', 's$i'),
              if (i < 2) _sec('sec$i', 's$i'),
            ],
          ),
      ];
      expect(
        _resolve(_snap(series, {'sec0': _owned('sec0')}), full: true)
            .scores[CollectorTypeArchetypeId.luckyOne],
        0,
      );
    });

    test('L4 Hunter eligible → Lucky One score 0', () {
      final s = _series(
        id: 'h',
        ipId: 'ip',
        figures: [_sec('a', 'h'), _sec('b', 'h')],
      );
      final r = _resolve(
        _snap([s], {'a': _owned('a'), 'b': _owned('b')}),
        full: true,
      );
      expect(r.scores[CollectorTypeArchetypeId.hunter], greaterThan(0));
      expect(r.scores[CollectorTypeArchetypeId.luckyOne], 0);
    });
  });

  group('LO / CU — Loyalist & Curator', () {
    test('LO1 3 of 5 one IP → Loyalist', () {
      final series = [
        for (var i = 0; i < 3; i++)
          _series(id: 'd$i', ipId: 'dimoo', figures: [_reg('x$i', 'd$i')]),
        _series(id: 'o0', ipId: 'other0', figures: [_reg('o0', 'o0')]),
        _series(id: 'o1', ipId: 'other1', figures: [_reg('o1', 'o1')]),
      ];
      expect(_resolve(_snap(series, {})), CollectorTypeArchetypeId.loyalist);
    });

    test('LO2 2 of 5 → not Loyalist', () {
      final series = [
        for (var i = 0; i < 2; i++)
          _series(id: 'd$i', ipId: 'dimoo', figures: [_reg('x$i', 'd$i')]),
        for (var i = 0; i < 3; i++)
          _series(id: 'o$i', ipId: 'ip_$i', figures: [_reg('o$i', 'o$i')]),
      ];
      expect(
        _resolve(_snap(series, {}), full: true)
            .scores[CollectorTypeArchetypeId.loyalist],
        0,
      );
    });

    test('LO3 1 of 1 → not Loyalist', () {
      final s = _series(id: 's', ipId: 'dimoo', figures: [_reg('r', 's')]);
      expect(
        _resolve(_snap([s], {}), full: true)
            .scores[CollectorTypeArchetypeId.loyalist],
        0,
      );
      expect(_resolve(_snap([s], {})), CollectorTypeArchetypeId.wanderer);
    });

    test('LO4 same brand many IPs → not Loyalist', () {
      final series = [
        for (var i = 0; i < 4; i++)
          _series(
            id: 's$i',
            ipId: 'ip_$i',
            brandId: 'pop_mart',
            figures: [_reg('r$i', 's$i')],
          ),
      ];
      expect(
        _resolve(_snap(series, {}), full: true)
            .scores[CollectorTypeArchetypeId.loyalist],
        0,
      );
    });

    test('LO5 brand fallback when most rows lack IP', () {
      // Two figures each so partial ownership avoids Completionist.
      final series = [
        for (var i = 0; i < 3; i++)
          ShelfSeries(
            id: 'b$i',
            name: 'B$i',
            brand: 'Indie',
            ipName: '',
            figures: [_reg('r${i}a', 'b$i'), _reg('r${i}b', 'b$i')],
            shelfAccent: const Color(0xFFE4F2EA),
            taxonomyBrandId: 'indie_lab',
            taxonomyIpId: null,
            catalogTemplateId: 'cat_b$i',
          ),
      ];
      final states = {
        for (final s in series) s.figures.first.id: _owned(s.figures.first.id),
      };
      final r = _resolve(_snap(series, states), full: true);
      expect(r.scores[CollectorTypeArchetypeId.loyalist], greaterThan(0));
      expect(r.archetypeId, CollectorTypeArchetypeId.loyalist);
    });

    test('CU1 3 IPs invested → Curator', () {
      final series = [
        for (var i = 0; i < 3; i++) _nRegs('c$i', 'ip_$i', 2),
      ];
      final states = {
        for (final s in series) ..._ownFirst(s, 1),
      };
      expect(
        _resolve(_snap(series, states)),
        CollectorTypeArchetypeId.curator,
      );
    });

    test('CU2 3 IPs shallow → not Curator', () {
      final series = [
        for (var i = 0; i < 3; i++) _nRegs('c$i', 'ip_$i', 10),
      ];
      final states = {
        for (final s in series) ..._ownFirst(s, 2),
      };
      expect(
        _resolve(_snap(series, states), full: true)
            .scores[CollectorTypeArchetypeId.curator],
        0,
      );
    });

    test('CU3 only 2 IPs → not Curator', () {
      final series = [
        _nRegs('a', 'ip_a', 2),
        _nRegs('b', 'ip_b', 2),
      ];
      final states = {
        for (final s in series) ..._ownAll(s),
      };
      expect(
        _resolve(_snap(series, states), full: true)
            .scores[CollectorTypeArchetypeId.curator],
        0,
      );
    });

    test('CU4 Loyalist eligible → Curator score 0', () {
      final series = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 'd$i',
            ipId: 'dimoo',
            figures: [_reg('a$i', 'd$i'), _reg('b$i', 'd$i')],
          ),
        _series(
          id: 'o',
          ipId: 'other',
          figures: [_reg('oa', 'o'), _reg('ob', 'o')],
        ),
      ];
      final states = {
        for (final s in series) s.figures.first.id: _owned(s.figures.first.id),
      };
      final r = _resolve(_snap(series, states), full: true);
      expect(r.archetypeId, CollectorTypeArchetypeId.loyalist);
      expect(r.scores[CollectorTypeArchetypeId.curator], 0);
    });

    test('CU5 same-brand multi-IP → Curator + copy', () {
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
      final r = _resolve(_snap(series, states), full: true);
      expect(r.archetypeId, CollectorTypeArchetypeId.curator);
      expect(r.scores[CollectorTypeArchetypeId.loyalist], 0);
      expect(
        CollectorTypeArchetypes.curator.flavorText,
        contains('thoughtfully build across multiple universes'),
      );
      expect(
        CollectorTypeCopy.becauseLine(r.reasonKey),
        'Because your shelf is a gallery of worlds you genuinely invest in.',
      );
    });
  });

  group('W — Wanderer', () {
    test('W1 empty → Wanderer', () {
      expect(
        _resolve(CollectionSnapshot.emptyTest()),
        CollectorTypeArchetypeId.wanderer,
      );
    });

    test('W2 one ordinary series → Wanderer', () {
      final s = _series(id: 's', ipId: 'ip', figures: [_reg('r', 's')]);
      expect(_resolve(_snap([s], {})), CollectorTypeArchetypeId.wanderer);
    });

    test('W3 mixed undefined → Wanderer', () {
      final series = [
        for (var i = 0; i < 4; i++) _nRegs('w$i', 'ip_$i', 10),
      ];
      final states = {
        for (final s in series) ..._ownFirst(s, 2),
      };
      expect(
        _resolve(_snap(series, states)),
        CollectorTypeArchetypeId.wanderer,
      );
    });

    test('W4 specialized beats Wanderer floor', () {
      final series = [
        for (var i = 0; i < 2; i++) _nRegs('m$i', 'ip_$i', 10),
      ];
      final states = {
        for (final s in series) ..._ownFirst(s, 7),
      };
      final r = _resolve(_snap(series, states), full: true);
      expect(r.archetypeId, CollectorTypeArchetypeId.minimalist);
      expect(
        r.scores[CollectorTypeArchetypeId.minimalist]! >
            r.scores[CollectorTypeArchetypeId.wanderer]!,
        isTrue,
      );
    });

    test('W5 Wanderer soft floor visible but non-competitive', () {
      final series = [
        for (var i = 0; i < 3; i++) _completeSeries('p$i', 'ip_$i'),
      ];
      final states = {
        ..._ownAll(series[0]),
        ..._ownAll(series[1]),
      };
      final r = _resolve(_snap(series, states), full: true);
      expect(r.scores[CollectorTypeArchetypeId.wanderer], 5);
      expect(r.archetypeId, isNot(CollectorTypeArchetypeId.wanderer));
      expect(
        r.scores[r.archetypeId]! > r.scores[CollectorTypeArchetypeId.wanderer]!,
        isTrue,
      );
    });
  });

  group('M — Minimalist', () {
    test('M1 3 series at 70% → qualifies', () {
      final series = [
        for (var i = 0; i < 3; i++) _nRegs('m$i', 'ip_$i', 10),
      ];
      final states = {
        for (final s in series) ..._ownFirst(s, 7),
      };
      expect(
        _resolve(_snap(series, states)),
        CollectorTypeArchetypeId.minimalist,
      );
    });

    test('M2 3 series at 69% → not Minimalist', () {
      // 69/100 each via 69 of 100 — use 69 of 100 for exactness.
      final series = [
        for (var i = 0; i < 3; i++) _nRegs('m$i', 'ip_$i', 100),
      ];
      final states = {
        for (final s in series) ..._ownFirst(s, 69),
      };
      expect(
        _resolve(_snap(series, states), full: true)
            .scores[CollectorTypeArchetypeId.minimalist],
        0,
      );
    });

    test('M3 4 series at 100% → not Minimalist', () {
      final series = [
        for (var i = 0; i < 4; i++) _completeSeries('s$i', 'ip_$i'),
      ];
      final states = {
        for (final s in series) ..._ownAll(s),
      };
      expect(
        _resolve(_snap(series, states), full: true)
            .scores[CollectorTypeArchetypeId.minimalist],
        0,
      );
    });

    test('M4 >12 owned figures still Minimalist', () {
      final series = [
        for (var i = 0; i < 2; i++) _nRegs('m$i', 'ip_$i', 10),
      ];
      final states = {
        for (final s in series) ..._ownFirst(s, 7),
      };
      expect(
        _resolve(_snap(series, states)),
        CollectorTypeArchetypeId.minimalist,
      );
    });

    test('M5 Minimalist vs Completionist collision report', () {
      // 2 series fully complete → both eligible.
      final series = [
        for (var i = 0; i < 2; i++) _completeSeries('m$i', 'ip_$i'),
      ];
      final states = {
        for (final s in series) ..._ownAll(s),
      };
      final r = _resolve(_snap(series, states), full: true);
      final mini = r.scores[CollectorTypeArchetypeId.minimalist]!;
      final comp = r.scores[CollectorTypeArchetypeId.completionist]!;
      // Tie-break: Completionist ranks above Minimalist.
      expect(comp, greaterThan(0));
      expect(mini, greaterThan(0));
      expect(r.archetypeId, CollectorTypeArchetypeId.completionist);
      final order = CollectorTypeArchetypes.tieBreakPriority;
      expect(
        order.indexOf(CollectorTypeArchetypeId.completionist),
        lessThan(order.indexOf(CollectorTypeArchetypeId.minimalist)),
      );
    });
  });

  group('WB — Worldbuilder', () {
    test('WB1 1 custom of 1 → not', () {
      final s = _series(
        id: 'c',
        ipId: 'c_ip',
        custom: true,
        figures: [_reg('r', 'c')],
      );
      expect(
        _resolve(_snap([s], {}), full: true)
            .scores[CollectorTypeArchetypeId.worldbuilder],
        0,
      );
    });

    test('WB2 2 of 3 custom → qualifies', () {
      final customs = [
        for (var i = 0; i < 2; i++)
          _series(
            id: 'c$i',
            ipId: 'c$i',
            custom: true,
            figures: [_reg('r$i', 'c$i')],
          ),
      ];
      final cat = _series(id: 'k', ipId: 'labubu', figures: [_reg('kr', 'k')]);
      expect(
        _resolve(_snap([...customs, cat], {})),
        CollectorTypeArchetypeId.worldbuilder,
      );
    });

    test('WB3 2 of 4 exact 50% → not', () {
      final customs = [
        for (var i = 0; i < 2; i++)
          _series(
            id: 'c$i',
            ipId: 'c$i',
            custom: true,
            figures: [_reg('r$i', 'c$i')],
          ),
      ];
      final cats = [
        for (var i = 0; i < 2; i++)
          _series(id: 'k$i', ipId: 'ip_$i', figures: [_reg('kr$i', 'k$i')]),
      ];
      expect(
        _resolve(_snap([...customs, ...cats], {}), full: true)
            .scores[CollectorTypeArchetypeId.worldbuilder],
        0,
      );
    });

    test('WB4 authorship deepens score after eligibility', () {
      final bare = [
        for (var i = 0; i < 2; i++)
          _series(
            id: 'c$i',
            ipId: 'c$i',
            custom: true,
            figures: [_reg('r$i', 'c$i')],
          ),
      ];
      final rich = [
        for (var i = 0; i < 2; i++)
          _series(
            id: 'c$i',
            ipId: 'c$i',
            custom: true,
            notes: 'lore',
            cover: '/cover.jpg',
            figurePhoto: '/fig.jpg',
            figures: [_reg('r$i', 'c$i')],
          ),
      ];
      final bareScore = _resolve(_snap(bare, {}), full: true)
          .scores[CollectorTypeArchetypeId.worldbuilder]!;
      final richScore = _resolve(_snap(rich, {}), full: true)
          .scores[CollectorTypeArchetypeId.worldbuilder]!;
      expect(bareScore, greaterThan(0));
      expect(richScore, greaterThan(bareScore));
    });

    test('WB5 catalog notes/covers do not count as authorship', () {
      // Product UI never attaches notes to catalog rows — assert custom-only path.
      final customs = [
        for (var i = 0; i < 2; i++)
          _series(
            id: 'c$i',
            ipId: 'c$i',
            custom: true,
            figures: [_reg('r$i', 'c$i')],
          ),
      ];
      final withCatalogNotesAttempt = [
        ...customs,
        // Catalog row cannot carry notes via helper (custom:false strips them).
        _series(id: 'k', ipId: 'labubu', figures: [_reg('kr', 'k')]),
      ];
      final r = _resolve(_snap(withCatalogNotesAttempt, {}), full: true);
      // Still Worldbuilder from 2/3 custom > 50%; catalog assets add nothing.
      expect(r.archetypeId, CollectorTypeArchetypeId.worldbuilder);
    });
  });

  group('D — Dreamer', () {
    test('D1 2 wishlist 1 owned → qualifies', () {
      final s = _series(
        id: 'd',
        ipId: 'ip',
        figures: [_reg('o', 'd'), _reg('w1', 'd'), _reg('w2', 'd')],
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

    test('D2 exact 50% → not', () {
      final s = _series(
        id: 'd',
        ipId: 'ip',
        figures: [
          _reg('o1', 'd'),
          _reg('o2', 'd'),
          _reg('w1', 'd'),
          _reg('w2', 'd'),
        ],
      );
      expect(
        _resolve(_snap([s], {
          'o1': _owned('o1'),
          'o2': _owned('o2'),
          'w1': _wish('w1'),
          'w2': _wish('w2'),
        }), full: true)
            .scores[CollectorTypeArchetypeId.dreamer],
        0,
      );
    });

    test('D3 one wishlist → not', () {
      final s = _series(
        id: 'd',
        ipId: 'ip',
        figures: [_reg('o', 'd'), _reg('w', 'd')],
      );
      expect(
        _resolve(_snap([s], {'w': _wish('w')}), full: true)
            .scores[CollectorTypeArchetypeId.dreamer],
        0,
      );
    });

    test('D4 untracked slots not in denominator', () {
      final s = _series(
        id: 'd',
        ipId: 'ip',
        figures: [
          _reg('o', 'd'),
          _reg('w1', 'd'),
          _reg('w2', 'd'),
          _reg('u1', 'd'),
          _reg('u2', 'd'),
          _reg('u3', 'd'),
        ],
      );
      final r = _resolve(
        _snap([s], {
          'o': _owned('o'),
          'w1': _wish('w1'),
          'w2': _wish('w2'),
          // u* remain untracked
        }),
        full: true,
      );
      expect(r.stats.totalOwned, 1);
      expect(r.stats.totalWishlist, 2);
      // ratio = 2/(1+2) > 0.5 — Dreamer; if untracked counted would be 2/6
      expect(r.archetypeId, CollectorTypeArchetypeId.dreamer);
    });
  });

  group('T — Trend Chaser', () {
    final now = DateTime(2026, 6, 1);

    test('T1 2 of 3 within 90 days → qualifies', () {
      final series = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 't$i',
            ipId: 'ip_$i',
            catalogTemplateId: 'cat_$i',
            figures: [_reg('r$i', 't$i')],
          ),
      ];
      final catalog = _catalog({
        'cat_0': '2026-05-01',
        'cat_1': '2026-04-15',
        'cat_2': '2025-01-01',
      });
      expect(
        _resolve(_snap(series, {}), catalog: catalog, now: now),
        CollectorTypeArchetypeId.trendChaser,
      );
    });

    test('T2 2 of 4 exact 50% → not', () {
      final series = [
        for (var i = 0; i < 4; i++)
          _series(
            id: 't$i',
            ipId: 'ip_$i',
            catalogTemplateId: 'cat_$i',
            figures: [_reg('r$i', 't$i')],
          ),
      ];
      final catalog = _catalog({
        'cat_0': '2026-05-01',
        'cat_1': '2026-04-15',
        'cat_2': '2025-01-01',
        'cat_3': '2024-01-01',
      });
      expect(
        _resolve(_snap(series, {}), catalog: catalog, now: now, full: true)
            .scores[CollectorTypeArchetypeId.trendChaser],
        0,
      );
    });

    test('T3 91 days ago → not recent', () {
      final series = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 't$i',
            ipId: 'ip_$i',
            catalogTemplateId: 'cat_$i',
            figures: [_reg('r$i', 't$i')],
          ),
      ];
      // now=2026-06-01 → clearly outside 90 days (old 180-day window would still count)
      final catalog = _catalog({
        'cat_0': '2025-12-01',
        'cat_1': '2025-12-01',
        'cat_2': '2025-12-01',
      });
      expect(
        now.difference(DateTime(2025, 12, 1)).inDays,
        greaterThan(90),
      );
      expect(
        _resolve(_snap(series, {}), catalog: catalog, now: now, full: true)
            .scores[CollectorTypeArchetypeId.trendChaser],
        0,
      );
    });

    test('T4 one recent → not', () {
      final series = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 't$i',
            ipId: 'ip_$i',
            catalogTemplateId: 'cat_$i',
            figures: [_reg('r$i', 't$i')],
          ),
      ];
      final catalog = _catalog({
        'cat_0': '2026-05-01',
        'cat_1': '2025-01-01',
        'cat_2': '2024-01-01',
      });
      expect(
        _resolve(_snap(series, {}), catalog: catalog, now: now, full: true)
            .scores[CollectorTypeArchetypeId.trendChaser],
        0,
      );
    });

    test('T5 exactly 90 days → counts as recent (inclusive)', () {
      // Implementation: now.difference(released).inDays <= 90
      final series = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 't$i',
            ipId: 'ip_$i',
            catalogTemplateId: 'cat_$i',
            figures: [_reg('r$i', 't$i')],
          ),
      ];
      // 2026-06-01 minus 90 days = 2026-03-03
      final catalog = _catalog({
        'cat_0': '2026-03-03',
        'cat_1': '2026-03-03',
        'cat_2': '2025-01-01',
      });
      expect(
        _resolve(_snap(series, {}), catalog: catalog, now: now),
        CollectorTypeArchetypeId.trendChaser,
      );
    });

    test('T6 aging invalidates Trend + signature', () {
      final series = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 't$i',
            ipId: 'ip_$i',
            catalogTemplateId: 'cat_$i',
            figures: [_reg('r$i', 't$i')],
          ),
      ];
      final catalog = _catalog({
        'cat_0': '2026-05-01',
        'cat_1': '2026-04-20',
        'cat_2': '2026-04-10',
      });
      final snap = _snap(series, {});
      final early = _resolve(
        snap,
        catalog: catalog,
        now: DateTime(2026, 6, 1),
        full: true,
      );
      final aged = _resolve(
        snap,
        catalog: catalog,
        now: DateTime(2026, 10, 1),
        full: true,
      );
      expect(early.archetypeId, CollectorTypeArchetypeId.trendChaser);
      expect(aged.archetypeId, isNot(CollectorTypeArchetypeId.trendChaser));
      expect(early.signatureHash, isNot(aged.signatureHash));
      expect(
        computeCollectorTypeNeedsReveal(
          hasRevealed: true,
          persistedSignatureHash: early.signatureHash,
          persistedResolverVersion: kCollectorTypeResolverVersion,
          liveCandidate: aged,
        ),
        isTrue,
      );
    });
  });

  group('Legacy 5.x rejection', () {
    test('40% complete share does not qualify Completionist', () {
      final series = [
        for (var i = 0; i < 5; i++) _completeSeries('s$i', 'ip_$i'),
      ];
      // 2/5 = 40%
      final states = {..._ownAll(series[0]), ..._ownAll(series[1])};
      expect(
        _resolve(_snap(series, states), full: true)
            .scores[CollectorTypeArchetypeId.completionist],
        0,
      );
    });

    test('35% Secret hit rate does not qualify Hunter', () {
      final figs = [
        for (var i = 0; i < 20; i++) _sec('s$i', 'h'),
      ];
      final s = _series(id: 'h', ipId: 'ip', figures: figs);
      // 7/20 = 35%
      final states = {
        for (var i = 0; i < 7; i++) 's$i': _owned('s$i'),
      };
      expect(
        _resolve(_snap([s], states), full: true)
            .scores[CollectorTypeArchetypeId.hunter],
        0,
      );
    });

    test('brand-only POP MART with diverse IPs is not Loyalist', () {
      final series = [
        for (var i = 0; i < 5; i++)
          _series(
            id: 's$i',
            ipId: 'ip_$i',
            brandId: 'pop_mart',
            figures: [_reg('r$i', 's$i')],
          ),
      ];
      expect(
        _resolve(_snap(series, {}), full: true)
            .scores[CollectorTypeArchetypeId.loyalist],
        0,
      );
    });

    test('2 IPs do not qualify Curator', () {
      final series = [
        _nRegs('a', 'ip_a', 2),
        _nRegs('b', 'ip_b', 2),
      ];
      expect(
        _resolve(_snap(series, {
          for (final s in series) ..._ownAll(s),
        }), full: true)
            .scores[CollectorTypeArchetypeId.curator],
        0,
      );
    });

    test('Wanderer does not require multiple brands', () {
      final s = _series(
        id: 's',
        ipId: 'ip',
        brandId: 'pop_mart',
        figures: [_reg('r', 's')],
      );
      expect(_resolve(_snap([s], {})), CollectorTypeArchetypeId.wanderer);
    });

    test('owned<=12 no longer gates Minimalist', () {
      final series = [
        for (var i = 0; i < 2; i++) _nRegs('m$i', 'ip_$i', 10),
      ];
      final states = {
        for (final s in series) ..._ownFirst(s, 8),
      };
      expect(states.length, greaterThan(12));
      expect(
        _resolve(_snap(series, states)),
        CollectorTypeArchetypeId.minimalist,
      );
    });

    test('30% custom does not qualify Worldbuilder', () {
      final customs = [
        _series(
          id: 'c0',
          ipId: 'c0',
          custom: true,
          figures: [_reg('r0', 'c0')],
        ),
      ];
      final cats = [
        for (var i = 0; i < 2; i++)
          _series(id: 'k$i', ipId: 'ip_$i', figures: [_reg('kr$i', 'k$i')]),
      ];
      // 1/3 ≈ 33%
      expect(
        _resolve(_snap([...customs, ...cats], {}), full: true)
            .scores[CollectorTypeArchetypeId.worldbuilder],
        0,
      );
    });

    test('45% wishlist does not qualify Dreamer', () {
      final s = _series(
        id: 'd',
        ipId: 'ip',
        figures: [
          for (var i = 0; i < 11; i++) _reg('f$i', 'd'),
        ],
      );
      // 5 wishlist / (6 owned + 5 wishlist) ≈ 45%
      final states = <String, TrackedFigure>{
        for (var i = 0; i < 6; i++) 'f$i': _owned('f$i'),
        for (var i = 6; i < 11; i++) 'f$i': _wish('f$i'),
      };
      expect(
        _resolve(_snap([s], states), full: true)
            .scores[CollectorTypeArchetypeId.dreamer],
        0,
      );
    });

    test('180-day-old series not recent; 40% recent not Trend', () {
      final now = DateTime(2026, 6, 1);
      final series = [
        for (var i = 0; i < 5; i++)
          _series(
            id: 't$i',
            ipId: 'ip_$i',
            catalogTemplateId: 'cat_$i',
            figures: [_reg('r$i', 't$i')],
          ),
      ];
      // 2 recent (40%) + 3 at ~150 days (within old 180, outside 90)
      final catalog = _catalog({
        'cat_0': '2026-05-01',
        'cat_1': '2026-04-20',
        'cat_2': '2026-01-01',
        'cat_3': '2026-01-15',
        'cat_4': '2025-12-01',
      });
      expect(
        _resolve(_snap(series, {}), catalog: catalog, now: now, full: true)
            .scores[CollectorTypeArchetypeId.trendChaser],
        0,
      );
    });
  });

  group('Whole-board winners + diagnostics', () {
    void dump(String label, dynamic r) {
      final scores = r.scores as Map<CollectorTypeArchetypeId, double>;
      final eligible = scores.entries
          .where((MapEntry<CollectorTypeArchetypeId, double> e) => e.value > 0)
          .map((e) => '${e.key.name}:${e.value.toStringAsFixed(1)}')
          .join(', ');
      // ignore: avoid_print
      print(
        '[$label] winner=${r.archetypeId} '
        'score=${r.score} confidence=${r.confidence} '
        'eligible=$eligible',
      );
    }

    test('representative winners', () {
      final cases = <String, CollectorTypeArchetypeId>{};

      // Completionist
      final comp = [
        for (var i = 0; i < 3; i++) _completeSeries('p$i', 'ip_$i'),
      ];
      final compR = _resolve(
        _snap(comp, {..._ownAll(comp[0]), ..._ownAll(comp[1])}),
        full: true,
      );
      dump('Completionist', compR);
      cases['Completionist'] = compR.archetypeId;

      // Lucky One
      final lucky = _series(
        id: 'l',
        ipId: 'ip',
        figures: [_reg('lr', 'l'), _sec('ls', 'l')],
      );
      final luckyR = _resolve(_snap([lucky], {'ls': _owned('ls')}), full: true);
      dump('LuckyOne', luckyR);
      cases['LuckyOne'] = luckyR.archetypeId;

      // Hunter
      final hunt = [
        for (var i = 0; i < 5; i++)
          _series(
            id: 'h$i',
            ipId: 'ip_$i',
            figures: [_reg('r$i', 'h$i'), _sec('s$i', 'h$i')],
          ),
      ];
      final huntR = _resolve(
        _snap(hunt, {for (var i = 0; i < 3; i++) 's$i': _owned('s$i')}),
        full: true,
      );
      dump('Hunter', huntR);
      cases['Hunter'] = huntR.archetypeId;

      // Loyalist
      final loyal = [
        for (var i = 0; i < 3; i++)
          _series(id: 'd$i', ipId: 'dimoo', figures: [_reg('x$i', 'd$i')]),
      ];
      final loyalR = _resolve(_snap(loyal, {}), full: true);
      dump('Loyalist', loyalR);
      cases['Loyalist'] = loyalR.archetypeId;

      // Curator
      final cur = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 'c$i',
            ipId: 'ip_$i',
            brandId: 'pop_mart',
            figures: [_reg('a$i', 'c$i'), _reg('b$i', 'c$i')],
          ),
      ];
      final curR = _resolve(
        _snap(cur, {
          for (final s in cur) s.figures.first.id: _owned(s.figures.first.id),
        }),
        full: true,
      );
      dump('Curator', curR);
      cases['Curator'] = curR.archetypeId;

      // Wanderer
      final wanR = _resolve(CollectionSnapshot.emptyTest(), full: true);
      dump('Wanderer', wanR);
      cases['Wanderer'] = wanR.archetypeId;

      // Minimalist
      final mini = [
        for (var i = 0; i < 2; i++) _nRegs('m$i', 'ip_$i', 10),
      ];
      final miniR = _resolve(
        _snap(mini, {for (final s in mini) ..._ownFirst(s, 7)}),
        full: true,
      );
      dump('Minimalist', miniR);
      cases['Minimalist'] = miniR.archetypeId;

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
      final wbR = _resolve(_snap(wb, {}), full: true);
      dump('Worldbuilder', wbR);
      cases['Worldbuilder'] = wbR.archetypeId;

      // Dreamer
      final dream = _series(
        id: 'dr',
        ipId: 'ip_a',
        figures: [_reg('o', 'dr'), _reg('w1', 'dr'), _reg('w2', 'dr')],
      );
      final dreamR = _resolve(
        _snap([dream], {
          'o': _owned('o'),
          'w1': _wish('w1'),
          'w2': _wish('w2'),
        }),
        full: true,
      );
      dump('Dreamer', dreamR);
      cases['Dreamer'] = dreamR.archetypeId;

      // Trend
      final now = DateTime(2026, 6, 1);
      final trend = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 't$i',
            ipId: 'tip_$i',
            catalogTemplateId: 'tcat_$i',
            figures: [_reg('tr$i', 't$i')],
          ),
      ];
      final trendCatalog = _catalog({
        for (var i = 0; i < 3; i++) 'tcat_$i': '2026-05-0${i + 1}',
      });
      final trendR = _resolve(
        _snap(trend, {}),
        catalog: trendCatalog,
        now: now,
        full: true,
      );
      dump('TrendChaser', trendR);
      cases['TrendChaser'] = trendR.archetypeId;

      expect(cases['Completionist'], CollectorTypeArchetypeId.completionist);
      expect(cases['LuckyOne'], CollectorTypeArchetypeId.luckyOne);
      expect(cases['Hunter'], CollectorTypeArchetypeId.hunter);
      expect(cases['Loyalist'], CollectorTypeArchetypeId.loyalist);
      expect(cases['Curator'], CollectorTypeArchetypeId.curator);
      expect(cases['Wanderer'], CollectorTypeArchetypeId.wanderer);
      expect(cases['Minimalist'], CollectorTypeArchetypeId.minimalist);
      expect(cases['Worldbuilder'], CollectorTypeArchetypeId.worldbuilder);
      expect(cases['Dreamer'], CollectorTypeArchetypeId.dreamer);
      expect(cases['TrendChaser'], CollectorTypeArchetypeId.trendChaser);
    });
  });

  group('R — Resolver lifecycle', () {
    test('R1 5.3 → 6.0 upgrade needsReveal, no silent rewrite', () {
      final series = [
        for (var i = 0; i < 3; i++)
          _series(id: 'd$i', ipId: 'dimoo', figures: [_reg('x$i', 'd$i')]),
      ];
      final live = _resolve(_snap(series, {}), full: true);
      expect(
        computeCollectorTypeNeedsReveal(
          hasRevealed: true,
          persistedSignatureHash: live.signatureHash,
          persistedResolverVersion: '5.3',
          liveCandidate: live,
        ),
        isTrue,
      );
      // Live candidate may differ from a frozen 5.3 identity — Hero stays
      // frozen until explicit Reveal (no silent rewrite in this pure check).
      expect(kCollectorTypeResolverVersion, '6.0');
    });

    test('R2/R3 after matching 6.0 persist → needsReveal false', () {
      final series = [
        for (var i = 0; i < 3; i++)
          _series(id: 'd$i', ipId: 'dimoo', figures: [_reg('x$i', 'd$i')]),
      ];
      final live = _resolve(_snap(series, {}), full: true);
      expect(
        computeCollectorTypeNeedsReveal(
          hasRevealed: true,
          persistedSignatureHash: live.signatureHash,
          persistedResolverVersion: kCollectorTypeResolverVersion,
          liveCandidate: live,
        ),
        isFalse,
      );
    });

    test('R4 Trend aging alone can produce needsReveal', () {
      final series = [
        for (var i = 0; i < 3; i++)
          _series(
            id: 't$i',
            ipId: 'ip_$i',
            catalogTemplateId: 'cat_$i',
            figures: [_reg('r$i', 't$i')],
          ),
      ];
      final catalog = _catalog({
        'cat_0': '2026-05-01',
        'cat_1': '2026-04-20',
        'cat_2': '2026-04-10',
      });
      final snap = _snap(series, {});
      final early = _resolve(
        snap,
        catalog: catalog,
        now: DateTime(2026, 6, 1),
        full: true,
      );
      final aged = _resolve(
        snap,
        catalog: catalog,
        now: DateTime(2026, 10, 1),
        full: true,
      );
      expect(
        computeCollectorTypeNeedsReveal(
          hasRevealed: true,
          persistedSignatureHash: early.signatureHash,
          persistedResolverVersion: kCollectorTypeResolverVersion,
          liveCandidate: aged,
        ),
        isTrue,
      );
    });
  });
}
