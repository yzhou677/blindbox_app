import 'package:blindbox_app/features/official_feed/data/official_feed_mapper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mapOfficialFeedItem accepts active Firestore-shaped doc', () {
    final published = DateTime.utc(2026, 5, 18, 10);
    final item = mapOfficialFeedItem('doc_a', {
      'id': 'doc_a',
      'sourceId': 'popmart_us',
      'sourceLabel': 'POP MART',
      'title': 'CRYBABY Cry Me an Ocean Series',
      'imageUrl': 'https://cdn-global.popmart.com/images/192.png',
      'officialUrl': 'https://www.popmart.com/us',
      'publishedAt': Timestamp.fromDate(published),
      'status': 'active',
      'contentHash': 'abc123',
      'locale': 'us',
    });

    expect(item, isNotNull);
    expect(item!.title, 'CRYBABY Cry Me an Ocean Series');
    expect(item.publishedAt.toUtc(), published);
    expect(item.sourceLabel, 'POP MART');
  });

  test('mapOfficialFeedItem rejects archived and non-https urls', () {
    expect(
      mapOfficialFeedItem('x', {
        'sourceId': 'popmart_us',
        'sourceLabel': 'POP MART',
        'title': 'T',
        'imageUrl': 'https://cdn.example.com/a.png',
        'officialUrl': 'https://www.popmart.com/us',
        'publishedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'status': 'archived',
        'contentHash': 'h',
      }),
      isNull,
    );

    expect(
      mapOfficialFeedItem('x', {
        'sourceId': 'popmart_us',
        'sourceLabel': 'POP MART',
        'title': 'T',
        'imageUrl': 'http://insecure.example.com/a.png',
        'officialUrl': 'https://www.popmart.com/us',
        'publishedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'status': 'active',
        'contentHash': 'h',
      }),
      isNull,
    );
  });
}
