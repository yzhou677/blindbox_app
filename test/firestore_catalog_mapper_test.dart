import 'package:blindbox_app/features/catalog/firestore/firestore_catalog_mapper.dart';
import 'package:blindbox_app/features/catalog/models/catalog_brand.dart';
import 'package:blindbox_app/features/catalog/models/catalog_figure.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('firestoreCatalogDocToJsonMap', () {
    test('uses document id when id field missing', () {
      final m = firestoreCatalogDocToJsonMap('pop_mart', {
        'displayName': 'POP MART',
        'aliases': <String>['POPMART'],
      });
      expect(m['id'], 'pop_mart');
    });

    test('converts Timestamp to YYYY-MM-DD for releaseDate', () {
      final ts = Timestamp.fromDate(DateTime.utc(2023, 10, 27, 15, 30));
      final m = firestoreCatalogDocToJsonMap('s1', {
        'brandId': 'b',
        'ipId': 'i',
        'displayName': 'Series',
        'releaseDate': ts,
        'isBlindBox': true,
        'thumbnailAsset': 'assets/x.png',
      });
      expect(m['releaseDate'], '2023-10-27');
    });
  });

  group('mapFirestore*', () {
    test('mapFirestoreBrand round-trip shape', () {
      final b = mapFirestoreBrand('pop_mart', {
        'displayName': 'POP MART',
        'aliases': <String>['POPMART'],
      });
      expect(b, isA<CatalogBrand>());
      expect(b!.id, 'pop_mart');
      expect(b.displayName, 'POP MART');
      expect(b.aliases, ['POPMART']);
    });

    test('mapFirestoreFigure coerces double sortOrder', () {
      final f = mapFirestoreFigure('fig_1', {
        'seriesId': 's',
        'brandId': 'b',
        'ipId': 'i',
        'displayName': 'Name',
        'isSecret': false,
        'sortOrder': 2.0,
        'thumbnailAsset': 'assets/f.png',
      });
      expect(f, isA<CatalogFigure>());
      expect(f!.sortOrder, 2);
    });

    test('mapFirestoreIp and mapFirestoreSeries', () {
      final ip = mapFirestoreIp('the_monsters', {
        'brandId': 'pop_mart',
        'displayName': 'The Monsters',
        'aliases': <String>[],
      });
      expect(ip!.id, 'the_monsters');

      final s = mapFirestoreSeries('the_monsters_exciting_macaron', {
        'brandId': 'pop_mart',
        'ipId': 'the_monsters',
        'displayName': 'Exciting Macaron',
        'releaseDate': '2023-10-27',
        'isBlindBox': true,
        'thumbnailAsset': 'assets/catalog/series/x.png',
      });
      expect(s!.displayName, 'Exciting Macaron');
    });

    test('mapFirestoreBrand fills id from document id when fields sparse', () {
      final b = mapFirestoreBrand('pop_mart', {});
      expect(b, isA<CatalogBrand>());
      expect(b!.id, 'pop_mart');
      expect(b.displayName, '');
    });
  });
}
