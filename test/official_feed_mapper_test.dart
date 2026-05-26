import 'package:blindbox_app/features/official_feed/data/official_feed_mapper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _activeDoc({
  required String imageUrl,
  required String officialUrl,
}) {
  return {
    'id': 'doc_a',
    'sourceId': 'popmart_us',
    'sourceLabel': 'POP MART',
    'title': 'CRYBABY Cry Me an Ocean Series',
    'imageUrl': imageUrl,
    'officialUrl': officialUrl,
    'publishedAt': Timestamp.fromDate(DateTime.utc(2026, 5, 18, 10)),
    'status': 'active',
    'contentHash': 'abc123',
    'locale': 'us',
    'summary': 'Vinyl plush pendants — online May 14',
  };
}

void main() {
  test('mapOfficialFeedItem accepts active doc with product url and art', () {
    final published = DateTime.utc(2026, 5, 18, 10);
    final item = mapOfficialFeedItem(
      'doc_a',
      _activeDoc(
        imageUrl:
            'https://cdn-global.popmart.com/nas/images/content/example/product.png',
        officialUrl:
            'https://www.popmart.com/us/products/6278/crybaby-cry-me-an-ocean-series-vinyl-plush-pendant-blind-box',
      ),
    );

    expect(item, isNotNull);
    expect(item!.title, 'CRYBABY Cry Me an Ocean Series');
    expect(item.publishedAt.toUtc(), published);
    expect(item.sourceLabel, 'POP MART');
    expect(item.summary, 'Vinyl plush pendants — online May 14');
  });

  test('mapOfficialFeedItem rejects homepage, placeholder image, archived', () {
    expect(
      mapOfficialFeedItem('x', {
        ..._activeDoc(
          imageUrl: 'https://cdn.example.com/a.png',
          officialUrl:
              'https://www.popmart.com/us/products/6278/crybaby-cry-me-an-ocean-series-vinyl-plush-pendant-blind-box',
        ),
        'status': 'archived',
      }),
      isNull,
    );

    expect(
      mapOfficialFeedItem(
        'x',
        _activeDoc(
          imageUrl: 'https://cdn-global.popmart.com/images/192.png',
          officialUrl:
              'https://www.popmart.com/us/products/6278/crybaby-cry-me-an-ocean-series-vinyl-plush-pendant-blind-box',
        ),
      ),
      isNull,
    );

    expect(
      mapOfficialFeedItem(
        'x',
        _activeDoc(
          imageUrl: 'https://cdn.example.com/a.png',
          officialUrl: 'https://www.popmart.com/us',
        ),
      ),
      isNull,
    );

    expect(
      mapOfficialFeedItem('x', {
        ..._activeDoc(
          imageUrl: 'https://cdn.example.com/a.png',
          officialUrl:
              'https://www.popmart.com/us/products/6278/crybaby-cry-me-an-ocean-series-vinyl-plush-pendant-blind-box',
        ),
        'imageUrl': 'http://insecure.example.com/a.png',
      }),
      isNull,
    );
  });

  test('mapOfficialFeedItem accepts pop-now set urls', () {
    final item = mapOfficialFeedItem(
      'pop_now',
      _activeDoc(
        imageUrl: 'https://cdn.example.com/monsters-have-a-seat.webp',
        officialUrl: 'https://www.popmart.com/us/pop-now/set/50-10009838800350',
      ),
    );
    expect(item, isNotNull);
  });

  test('mapOfficialFeedItem rejects slug-only product paths', () {
    expect(
      mapOfficialFeedItem(
        'x',
        _activeDoc(
          imageUrl: 'https://cdn.example.com/a.png',
          officialUrl:
              'https://www.popmart.com/us/products/skullpanda-x-my-little-pony-series-plush-doll-pendant-blind-box',
        ),
      ),
      isNull,
    );
  });
}
