import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/catalog/data/catalog_bundle_lookup.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart'
    as catalog_figure;
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart'
    as catalog_series;
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/material.dart';

/// Fixed reference instant for Collection browse logic tests (never `DateTime.now`).
final DateTime kCollectionLogicFixtureNow = DateTime.utc(2026, 7, 29, 12);

/// Compact deterministic shelf matrix for filter/sort unit tests.
///
/// Stable IDs and fixed catalog release dates. Do not rely on wall-clock time,
/// locale, Firebase, or production catalog bundles.
final class CollectionShelfLogicFixtures {
  CollectionShelfLogicFixtures._();

  static const accent = Color(0xFFE4F2EA);

  /// Micros for “collection activity” fixtures (shelf encounter order uses list
  /// order for [CollectionShelfSort.recentlyAdded]; these stamp figure updates).
  static const int tOldest = 1_700_000_000_000_000;
  static const int tMid = 1_720_000_000_000_000;
  static const int tNewest = 1_740_000_000_000_000;

  static ShelfFigure fig(
    String id,
    String seriesId, {
    String name = 'Fig',
    bool secret = false,
    String? catalogFigureTemplateId,
  }) {
    return ShelfFigure(
      id: id,
      seriesId: seriesId,
      name: name,
      rarity: secret ? '1:144' : 'Regular',
      isSecret: secret,
      catalogFigureTemplateId: catalogFigureTemplateId,
    );
  }

  static TrackedFigure owned(String id, {int qty = 1, int? updatedAtMicros}) {
    return TrackedFigure(
      figureId: id,
      state: FigureCollectionState.owned,
      ownedQuantity: qty,
      updatedAtMicros: updatedAtMicros,
    );
  }

  static TrackedFigure wish(String id, {int? updatedAtMicros}) {
    return TrackedFigure(
      figureId: id,
      state: FigureCollectionState.wishlist,
      updatedAtMicros: updatedAtMicros,
    );
  }

  /// Sentinel so callers can pass `catalogTemplateId: null` for custom series
  /// without `?? 'cat_$id'` swallowing explicit null.
  static const Object _defaultCatalogTemplate = Object();

  static ShelfSeries series({
    required String id,
    required String name,
    String brand = 'POP MART',
    String ipName = 'Hirono',
    String? taxonomyBrandId = 'pop_mart',
    String? taxonomyIpId = 'hirono',
    Object? catalogTemplateId = _defaultCatalogTemplate,
    List<ShelfFigure>? figures,
  }) {
    final String? resolvedTemplateId =
        identical(catalogTemplateId, _defaultCatalogTemplate)
        ? 'cat_$id'
        : catalogTemplateId as String?;
    return ShelfSeries(
      id: id,
      name: name,
      brand: brand,
      ipName: ipName,
      figures:
          figures ??
          [fig('${id}_r0', id, catalogFigureTemplateId: '${id}_tpl_r0')],
      shelfAccent: accent,
      catalogTemplateId: resolvedTemplateId,
      taxonomyBrandId: taxonomyBrandId,
      taxonomyIpId: taxonomyIpId,
    );
  }

  /// Full matrix used by filter + sort + pipeline tests.
  static CollectionShelfLogicMatrix build() {
    // Shelf encounter order (Recently Added preserves this):
    // alpha_mixed, bravo_dups, charlie_wish, delta_secret_owned,
    // echo_secret_missing, foxtrot_custom, golf_complete, hotel_no_meta,
    // india_name_secret, juliet_low_complete, kilo_many_figs
    final alphaMixed = series(
      id: 'alpha_mixed',
      name: 'alpha Series',
      catalogTemplateId: 'cat_alpha',
      figures: [
        fig('a_r0', 'alpha_mixed', catalogFigureTemplateId: 'cat_alpha_r0'),
        fig('a_r1', 'alpha_mixed', catalogFigureTemplateId: 'cat_alpha_r1'),
      ],
    );
    final bravoDups = series(
      id: 'bravo_dups',
      name: 'Bravo Dupes',
      catalogTemplateId: 'cat_bravo',
      figures: [
        fig('b_r0', 'bravo_dups', catalogFigureTemplateId: 'cat_bravo_r0'),
        fig('b_r1', 'bravo_dups', catalogFigureTemplateId: 'cat_bravo_r1'),
      ],
    );
    final charlieWish = series(
      id: 'charlie_wish',
      name: 'Charlie Wishlist',
      brand: 'TOP TOY',
      taxonomyBrandId: 'toptoy',
      ipName: 'Skullpanda',
      taxonomyIpId: 'skullpanda',
      catalogTemplateId: 'cat_charlie',
      figures: [
        fig('c_r0', 'charlie_wish', catalogFigureTemplateId: 'cat_charlie_r0'),
        fig('c_r1', 'charlie_wish', catalogFigureTemplateId: 'cat_charlie_r1'),
      ],
    );
    final deltaSecretOwned = series(
      id: 'delta_secret_owned',
      name: 'Delta Secret Owned',
      brand: 'TOP TOY',
      taxonomyBrandId: 'toptoy',
      ipName: 'Skullpanda',
      taxonomyIpId: 'skullpanda',
      catalogTemplateId: 'cat_delta',
      figures: [
        fig(
          'd_r0',
          'delta_secret_owned',
          catalogFigureTemplateId: 'cat_delta_r0',
        ),
        fig(
          'd_s0',
          'delta_secret_owned',
          secret: true,
          catalogFigureTemplateId: 'cat_delta_s0',
        ),
      ],
    );
    final echoSecretMissing = series(
      id: 'echo_secret_missing',
      name: 'Echo Secret Missing',
      catalogTemplateId: 'cat_echo',
      figures: [
        fig(
          'e_r0',
          'echo_secret_missing',
          catalogFigureTemplateId: 'cat_echo_r0',
        ),
        fig(
          'e_s0',
          'echo_secret_missing',
          secret: true,
          catalogFigureTemplateId: 'cat_echo_s0',
        ),
        fig(
          'e_s1',
          'echo_secret_missing',
          secret: true,
          catalogFigureTemplateId: 'cat_echo_s1',
        ),
      ],
    );
    final foxtrotCustom = series(
      id: 'foxtrot_custom',
      name: 'Foxtrot Custom',
      brand: 'Independent',
      taxonomyBrandId: 'independent',
      ipName: 'Custom IP',
      taxonomyIpId: 'custom_ip',
      catalogTemplateId: null,
      figures: [fig('f_r0', 'foxtrot_custom')],
    );
    final golfComplete = series(
      id: 'golf_complete',
      name: 'Golf Complete',
      catalogTemplateId: 'cat_golf',
      figures: [
        fig('g_r0', 'golf_complete', catalogFigureTemplateId: 'cat_golf_r0'),
        fig('g_r1', 'golf_complete', catalogFigureTemplateId: 'cat_golf_r1'),
        fig(
          'g_s0',
          'golf_complete',
          secret: true,
          catalogFigureTemplateId: 'cat_golf_s0',
        ),
      ],
    );
    final hotelNoMeta = series(
      id: 'hotel_no_meta',
      name: 'Hotel No Meta',
      brand: '',
      ipName: '',
      taxonomyBrandId: null,
      taxonomyIpId: null,
      catalogTemplateId: 'cat_hotel',
      figures: [
        fig('h_r0', 'hotel_no_meta', catalogFigureTemplateId: 'cat_hotel_r0'),
      ],
    );
    // Name contains "Secret" but isSecret is false — must not match Secret filters.
    final indiaNameSecret = series(
      id: 'india_name_secret',
      name: 'India Regular',
      catalogTemplateId: 'cat_india',
      figures: [
        fig(
          'i_r0',
          'india_name_secret',
          name: 'Secret Chase Lookalike',
          secret: false,
          catalogFigureTemplateId: 'cat_india_r0',
        ),
      ],
    );
    final julietLow = series(
      id: 'juliet_low',
      name: 'Juliet Low',
      catalogTemplateId: 'cat_juliet',
      figures: [
        for (var i = 0; i < 4; i++)
          fig('j_r$i', 'juliet_low', catalogFigureTemplateId: 'cat_juliet_r$i'),
      ],
    );
    final kiloMany = series(
      id: 'kilo_many',
      name: 'Kilo Many',
      brand: 'ROLIFE',
      taxonomyBrandId: 'rolife',
      ipName: 'Molly',
      taxonomyIpId: 'molly',
      catalogTemplateId: 'cat_kilo',
      figures: [
        for (var i = 0; i < 6; i++)
          fig('k_r$i', 'kilo_many', catalogFigureTemplateId: 'cat_kilo_r$i'),
      ],
    );
    // Same normalized name as alpha for alphabetical secondary-key tests.
    final limaAlphaCase = series(
      id: 'lima_alpha_case',
      name: 'Alpha Series',
      catalogTemplateId: 'cat_lima',
      figures: [
        fig('l_r0', 'lima_alpha_case', catalogFigureTemplateId: 'cat_lima_r0'),
      ],
    );

    final shelf = <ShelfSeries>[
      alphaMixed,
      bravoDups,
      charlieWish,
      deltaSecretOwned,
      echoSecretMissing,
      foxtrotCustom,
      golfComplete,
      hotelNoMeta,
      indiaNameSecret,
      julietLow,
      kiloMany,
      limaAlphaCase,
    ];

    final states = <String, TrackedFigure>{
      // alpha: 1/2 owned, qty 1
      'a_r0': owned('a_r0', updatedAtMicros: tMid),
      // bravo: duplicate on first figure
      'b_r0': owned('b_r0', qty: 3, updatedAtMicros: tNewest),
      'b_r1': owned('b_r1', qty: 1, updatedAtMicros: tNewest),
      // charlie: one owned + one wishlist
      'c_r0': owned('c_r0', updatedAtMicros: tOldest),
      'c_r1': wish('c_r1', updatedAtMicros: tOldest),
      // delta: regular + secret owned (qty 1 — keeps Has Duplicates isolated to bravo)
      'd_r0': owned('d_r0'),
      'd_s0': owned('d_s0'),
      // echo: regular owned, one secret owned, one secret missing
      'e_r0': owned('e_r0'),
      'e_s0': owned('e_s0'),
      // foxtrot custom owned
      'f_r0': owned('f_r0'),
      // golf: regulars complete, secret missing → Completed (not Master)
      'g_r0': owned('g_r0'),
      'g_r1': owned('g_r1'),
      // hotel: owned
      'h_r0': owned('h_r0'),
      // india: owned lookalike
      'i_r0': owned('i_r0'),
      // juliet: 1/4
      'j_r0': owned('j_r0'),
      // kilo: 2/6
      'k_r0': owned('k_r0'),
      'k_r1': owned('k_r1'),
      // lima: owned
      'l_r0': owned('l_r0'),
    };

    final catalogBundle = CatalogSeedBundle(
      brands: const [
        CatalogBrand(id: 'pop_mart', displayName: 'POP MART'),
        CatalogBrand(id: 'toptoy', displayName: 'TOP TOY'),
        CatalogBrand(id: 'rolife', displayName: 'Rolife'),
      ],
      ips: const [
        CatalogIp(id: 'hirono', brandId: 'pop_mart', displayName: 'Hirono'),
        CatalogIp(
          id: 'skullpanda',
          brandId: 'toptoy',
          displayName: 'Skullpanda',
        ),
        CatalogIp(id: 'molly', brandId: 'rolife', displayName: 'Molly'),
      ],
      series: [
        catSeries('cat_alpha', '2024-01-15'),
        catSeries('cat_bravo', '2025-06-01'),
        catSeries(
          'cat_charlie',
          '2023-03-01',
          brandId: 'toptoy',
          ipId: 'skullpanda',
        ),
        catSeries(
          'cat_delta',
          '2026-01-01',
          brandId: 'toptoy',
          ipId: 'skullpanda',
        ),
        catSeries('cat_echo', '2022-12-01'),
        catSeries('cat_golf', '2025-12-15'),
        catSeries('cat_hotel', 'not-a-date'), // malformed → sorts last
        catSeries('cat_india', null), // missing
        catSeries('cat_juliet', '2024-06-01'),
        catSeries('cat_kilo', '2026-07-01', brandId: 'rolife', ipId: 'molly'),
        catSeries(
          'cat_lima',
          '2024-01-15',
        ), // same date as alpha → name/id tie-break
      ],
      figures: [
        catFig('cat_alpha_r0', 'cat_alpha', secret: false),
        catFig('cat_alpha_r1', 'cat_alpha', secret: false),
        catFig('cat_bravo_r0', 'cat_bravo', secret: false),
        catFig('cat_bravo_r1', 'cat_bravo', secret: false),
        catFig(
          'cat_charlie_r0',
          'cat_charlie',
          secret: false,
          brandId: 'toptoy',
          ipId: 'skullpanda',
        ),
        catFig(
          'cat_charlie_r1',
          'cat_charlie',
          secret: false,
          brandId: 'toptoy',
          ipId: 'skullpanda',
        ),
        catFig(
          'cat_delta_r0',
          'cat_delta',
          secret: false,
          brandId: 'toptoy',
          ipId: 'skullpanda',
        ),
        catFig(
          'cat_delta_s0',
          'cat_delta',
          secret: true,
          brandId: 'toptoy',
          ipId: 'skullpanda',
        ),
        catFig('cat_echo_r0', 'cat_echo', secret: false),
        catFig('cat_echo_s0', 'cat_echo', secret: true),
        catFig('cat_echo_s1', 'cat_echo', secret: true),
        catFig('cat_golf_r0', 'cat_golf', secret: false),
        catFig('cat_golf_r1', 'cat_golf', secret: false),
        catFig('cat_golf_s0', 'cat_golf', secret: true),
        catFig('cat_hotel_r0', 'cat_hotel', secret: false),
        catFig('cat_india_r0', 'cat_india', secret: false),
        for (var i = 0; i < 4; i++)
          catFig('cat_juliet_r$i', 'cat_juliet', secret: false),
        for (var i = 0; i < 6; i++)
          catFig(
            'cat_kilo_r$i',
            'cat_kilo',
            secret: false,
            brandId: 'rolife',
            ipId: 'molly',
          ),
        catFig('cat_lima_r0', 'cat_lima', secret: false),
      ],
    );

    return CollectionShelfLogicMatrix(
      shelfSeries: shelf,
      figureStates: states,
      catalogBundle: catalogBundle,
      catalogLookup: CatalogBundleLookup.fromBundle(catalogBundle),
      now: kCollectionLogicFixtureNow,
    );
  }

  static catalog_series.CatalogSeries catSeries(
    String id,
    String? releaseDate, {
    String brandId = 'pop_mart',
    String ipId = 'hirono',
  }) {
    return catalog_series.CatalogSeries(
      id: id,
      brandId: brandId,
      ipId: ipId,
      displayName: id,
      releaseDate: releaseDate,
      isBlindBox: true,
      imageKey: id,
    );
  }

  static catalog_figure.CatalogFigure catFig(
    String id,
    String seriesId, {
    required bool secret,
    String brandId = 'pop_mart',
    String ipId = 'hirono',
  }) {
    return catalog_figure.CatalogFigure(
      id: id,
      seriesId: seriesId,
      brandId: brandId,
      ipId: ipId,
      displayName: id,
      isSecret: secret,
      sortOrder: 0,
      imageKey: id,
    );
  }
}

@immutable
final class CollectionShelfLogicMatrix {
  const CollectionShelfLogicMatrix({
    required this.shelfSeries,
    required this.figureStates,
    required this.catalogBundle,
    required this.catalogLookup,
    required this.now,
  });

  final List<ShelfSeries> shelfSeries;
  final Map<String, TrackedFigure> figureStates;
  final CatalogSeedBundle catalogBundle;
  final CatalogBundleLookup catalogLookup;
  final DateTime now;

  List<String> get allIds => [for (final s in shelfSeries) s.id];

  ShelfSeries byId(String id) => shelfSeries.firstWhere((s) => s.id == id);
}
