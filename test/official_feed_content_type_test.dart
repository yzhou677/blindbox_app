import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_sources.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_content_type.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_copy.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_source_presenter.dart';
import 'package:flutter_test/flutter_test.dart';

OfficialFeedItem _item({
  required String title,
  required String officialUrl,
  String? summary,
  String? releaseType,
}) {
  return OfficialFeedItem(
    id: 'test',
    sourceId: OfficialFeedSources.popmartUs,
    sourceLabel: 'POP MART',
    title: title,
    imageUrl: 'https://cdn.example.com/a.png',
    officialUrl: officialUrl,
    publishedAt: DateTime.utc(2026, 5, 18),
    contentHash: 'x',
    summary: summary,
    releaseType: releaseType,
  );
}

void main() {
  test('infer labels for curated seed scenarios', () {
    expect(
      inferOfficialFeedContentTypeLabel(
        _item(
          title: 'CRYBABY Cry Me an Ocean Series — Vinyl Plush Pendant Blind Box',
          summary: 'Vinyl plush pendants — online May 14, 7:00 PM PT',
          officialUrl:
              'https://www.popmart.com/us/products/6278/crybaby-cry-me-an-ocean-series-vinyl-plush-pendant-blind-box',
          releaseType: 'product',
        ),
      ),
      'Announcement',
    );

    expect(
      inferOfficialFeedContentTypeLabel(
        _item(
          title: 'CRYBABY Tears Launch Project Series — Plush Pendant Blind Box',
          summary: 'Plush pendants — online Feb 19, 6:00 PM PT',
          officialUrl:
              'https://www.popmart.com/us/products/5820/crybaby-tears-launch-project-series-plush-pendant-blind-box',
        ),
      ),
      'Announcement',
    );

    expect(
      inferOfficialFeedContentTypeLabel(
        _item(
          title: 'THE MONSTERS — Have a Seat Vinyl Plush Blind Box',
          summary: 'POP NOW vinyl plush blind box — \$27.99',
          officialUrl: 'https://www.popmart.com/us/pop-now/set/50-10009838800350',
          releaseType: 'pop_now',
        ),
      ),
      'POP NOW',
    );

    expect(
      inferOfficialFeedContentTypeLabel(
        _item(
          title: 'THE MONSTERS — Exciting Macaron Vinyl Face Blind Box',
          summary: 'Tasty Macarons vinyl face blind box — \$27.99',
          officialUrl:
              'https://www.popmart.com/us/products/675/the-monsters-exciting-macaron-vinyl-face-blind-box',
        ),
      ),
      'Product Spotlight',
    );

    expect(
      inferOfficialFeedContentTypeLabel(
        _item(
          title: 'SKULLPANDA × My Little Pony Series Plush Doll Pendant',
          summary: 'Plush doll pendants — eight styles',
          officialUrl:
              'https://www.popmart.com/us/products/6200/skullpanda-x-my-little-pony-series-plush-doll-pendant-blind-box',
        ),
      ),
      'Collaboration',
    );
  });

  test('falls back when no rule matches', () {
    expect(
      inferOfficialFeedContentTypeLabel(
        _item(
          title: 'POP MART community news',
          summary: 'Read the latest blog post',
          officialUrl: 'https://www.popmart.com/us/blog/some-post',
        ),
      ),
      OfficialFeedCopy.fallbackDeckLine,
    );
  });

  test('officialFeedDeckLine never uses New Releases wording', () {
    final item = _item(
      title: 'CRYBABY Cry Me an Ocean Series',
      summary: 'online May 14',
      officialUrl:
          'https://www.popmart.com/us/products/6278/crybaby-cry-me-an-ocean-series-vinyl-plush-pendant-blind-box',
    );
    final deck = officialFeedDeckLine(item);
    expect(deck, isNot(contains('New Releases')));
    expect(deck, 'Announcement');
  });
}
