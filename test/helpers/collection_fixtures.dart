import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/material.dart';

/// Minimal shelf row for unit tests.
ShelfSeries testShelfSeries({
  String id = 'series_test',
  String name = 'Test Series',
  String brand = 'POP MART',
  String ipName = 'Test IP',
  String? catalogTemplateId = 'catalog_series_test',
  String? imageKey,
  String? taxonomyBrandId = 'pop_mart',
  String? taxonomyIpId = 'the_monsters',
  List<ShelfFigure>? figures,
}) {
  return ShelfSeries(
    id: id,
    name: name,
    brand: brand,
    ipName: ipName,
    figures: figures ??
        [
          const ShelfFigure(
            id: 'fig_test_0',
            seriesId: 'series_test',
            name: 'Test Figure',
            rarity: 'Regular',
            isSecret: false,
            catalogFigureTemplateId: 'fig_catalog_0',
          ),
        ],
    shelfAccent: const Color(0xFFE4F2EA),
    catalogTemplateId: catalogTemplateId,
    imageKey: imageKey,
    taxonomyBrandId: taxonomyBrandId,
    taxonomyIpId: taxonomyIpId,
  );
}

CatalogSeries testCatalogTemplate({
  String templateId = 'catalog_series_test',
  String name = 'Catalog Series',
  String taxonomyIpId = 'the_monsters',
  List<CatalogFigure>? figures,
}) {
  return CatalogSeries(
    templateId: templateId,
    name: name,
    brand: 'POP MART',
    ipName: taxonomyIpId == 'nommi' ? 'NOMMI' : 'THE MONSTERS',
    shelfAccent: const Color(0xFFE4F2EA),
    taxonomyBrandId: 'pop_mart',
    taxonomyIpId: taxonomyIpId,
    figures: figures ??
        [
          CatalogFigure(
            templateFigureId: 'fig_catalog_0',
            catalogSeriesTemplateId: templateId,
            name: 'Secret Chase',
            catalogImageKey: 'fig_catalog_0',
            rarity: '1:144',
            isSecret: true,
          ),
          CatalogFigure(
            templateFigureId: 'fig_catalog_1',
            catalogSeriesTemplateId: templateId,
            name: 'Regular',
            catalogImageKey: 'fig_catalog_1',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
  );
}
