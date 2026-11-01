import 'package:blindbox_app/features/catalog/firestore/firestore_catalog_mapper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapFirestoreSeries', () {
    test(
      'parses live-shaped series doc with aliases and Timestamp releaseDate',
      () {
        final mapped = mapFirestoreSeries(
          'aespa_fluffy_club_vinyl_plush_doll_pendant_series',
          {
            'aliases': [
              'aespa Fluffy Club Series',
              'aespa fluffy club vinyl plush doll pendant',
            ],
            'brandId': 'pop_mart',
            'displayName': 'aespa Fluffy Club Series Vinyl Plush Doll Pendant',
            'id': 'aespa_fluffy_club_vinyl_plush_doll_pendant_series',
            'imageKey': 'aespa_fluffy_club_vinyl_plush_doll_pendant_series',
            'ipId': 'aespa',
            'isBlindBox': true,
            'releaseDate': Timestamp.fromDate(DateTime.utc(2026, 4, 30)),
          },
        );
        expect(mapped, isNotNull);
        final s = mapped!;
        expect(s.id, 'aespa_fluffy_club_vinyl_plush_doll_pendant_series');
        expect(s.imageKey, s.id);
        expect(s.releaseDate, '2026-04-30');
        expect(s.aliases, hasLength(2));
      },
    );
  });

  group('mapFirestoreFigure', () {
    test('parses live-shaped figure doc with null rarityLabel', () {
      final mapped = mapFirestoreFigure(
        'aespa_fluffy_club_vinyl_plush_doll_pendant_series_fiuffy_gelbulnyangi_giselle_ver',
        {
          'brandId': 'pop_mart',
          'displayName': 'Fluffy GELBULNYANGI(GISELLE VER.)',
          'id':
              'aespa_fluffy_club_vinyl_plush_doll_pendant_series_fiuffy_gelbulnyangi_giselle_ver',
          'imageKey':
              'aespa_fluffy_club_vinyl_plush_doll_pendant_series_fiuffy_gelbulnyangi_giselle_ver',
          'ipId': 'aespa',
          'isSecret': false,
          'rarityLabel': null,
          'seriesId': 'aespa_fluffy_club_vinyl_plush_doll_pendant_series',
          'sortOrder': 2,
        },
      );
      expect(mapped, isNotNull);
      final f = mapped!;
      expect(f.imageKey, f.id);
      expect(f.rarityLabel, isNull);
      expect(f.seriesId, 'aespa_fluffy_club_vinyl_plush_doll_pendant_series');
    });

    test('skips figure without seriesId', () {
      final mapped = mapFirestoreFigure('fig_orphan', {
        'brandId': 'pop_mart',
        'displayName': 'Orphan',
        'imageKey': 'fig_orphan',
        'ipId': 'aespa',
        'isSecret': false,
        'sortOrder': 1,
      });
      expect(mapped, isNull);
    });

    test('reads updatedAt and imageVersion including alternativeImages', () {
      final mapped = mapFirestoreFigure('fig_1', {
        'brandId': 'pop_mart',
        'displayName': 'Fig',
        'imageKey': 'fig_1',
        'ipId': 'aespa',
        'isSecret': false,
        'seriesId': 'series_1',
        'sortOrder': 1,
        'imageVersion': 'primaryMd5',
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 4, 2, 8)),
        'alternativeImages': [
          {
            'imageKey': 'fig_1_alt',
            'variant': 'box',
            'imageVersion': 'altMd5',
          },
        ],
      });
      expect(mapped, isNotNull);
      expect(mapped!.imageVersion, 'primaryMd5');
      expect(mapped.updatedAt, DateTime.utc(2026, 4, 2, 8));
      expect(mapped.alternativeImages.single.imageVersion, 'altMd5');
    });

    test('tolerates docs missing updatedAt and imageVersion', () {
      final mapped = mapFirestoreFigure('fig_2', {
        'brandId': 'pop_mart',
        'displayName': 'Fig',
        'imageKey': 'fig_2',
        'ipId': 'aespa',
        'isSecret': false,
        'seriesId': 'series_1',
        'sortOrder': 1,
      });
      expect(mapped, isNotNull);
      expect(mapped!.imageVersion, isNull);
      expect(mapped.updatedAt, isNull);
    });
  });

  group('mapFirestoreBrand / Series sync fields', () {
    test('brand and series accept Timestamp updatedAt', () {
      final brand = mapFirestoreBrand('pop_mart', {
        'displayName': 'POP MART',
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 3, 1)),
      });
      expect(brand?.updatedAt, DateTime.utc(2026, 3, 1));

      final series = mapFirestoreSeries('s1', {
        'brandId': 'pop_mart',
        'ipId': 'aespa',
        'displayName': 'S',
        'imageKey': 's1',
        'isBlindBox': true,
        'imageVersion': 'coverMd5',
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 3, 2)),
      });
      expect(series?.imageVersion, 'coverMd5');
      expect(series?.updatedAt, DateTime.utc(2026, 3, 2));
    });
  });
}
