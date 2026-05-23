import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:blindbox_app/features/catalog/models/catalog_ip.dart';
import 'package:blindbox_app/features/catalog/models/catalog_series.dart';

/// Minimal catalog bundle for identity-matching unit tests.
CatalogSeedBundle marketIdentityTestBundle() {
  const brand = CatalogBrand(
    id: 'pop_mart',
    displayName: 'POP MART',
    aliases: ['POPMART'],
  );
  const ip = CatalogIp(
    id: 'the_monsters',
    brandId: 'pop_mart',
    displayName: 'THE MONSTERS',
    aliases: ['MONSTERS'],
  );
  const series = CatalogSeries(
    id: 'series_macaron',
    brandId: 'pop_mart',
    ipId: 'the_monsters',
    displayName: 'Exciting Macaron',
    releaseDate: '2026-03-20',
    isBlindBox: true,
    imageKey: 'series_macaron',
    aliases: ['Macaron'],
  );
  const labubu = CatalogFigure(
    id: 'fig_labubu_pink',
    seriesId: 'series_macaron',
    brandId: 'pop_mart',
    ipId: 'the_monsters',
    displayName: 'Labubu Pink',
    isSecret: false,
    sortOrder: 1,
    imageKey: 'fig_labubu_pink',
  );
  const labubuSecret = CatalogFigure(
    id: 'fig_labubu_secret_pink',
    seriesId: 'series_macaron',
    brandId: 'pop_mart',
    ipId: 'the_monsters',
    displayName: 'Labubu Secret Pink',
    isSecret: true,
    rarityLabel: '1/72',
    sortOrder: 2,
    imageKey: 'fig_labubu_secret_pink',
  );
  return const CatalogSeedBundle(
    brands: [brand],
    ips: [ip],
    series: [series],
    figures: [labubu, labubuSecret],
  );
}
