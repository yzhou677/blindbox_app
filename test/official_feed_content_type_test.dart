import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_sources.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_content_type.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_copy.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_source_presenter.dart';
import 'package:blindbox_app/features/official_feed/widgets/official_feed_content_type_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

OfficialFeedItem _item({
  required String title,
  required String officialUrl,
  String? summary,
  String? releaseType,
  String sourceId = OfficialFeedSources.popmartUs,
  String sourceLabel = 'POP MART',
}) {
  return OfficialFeedItem(
    id: 'test',
    sourceId: sourceId,
    sourceLabel: sourceLabel,
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
  test('all curated brands use bundled logos', () {
    expect(
      officialFeedSourceLogoAsset(OfficialFeedSources.popmartUs),
      'assets/official_feed/popmart_logo.png',
    );
    expect(
      officialFeedSourceLogoAsset(OfficialFeedSources.tntspaceUs),
      'assets/official_feed/tntspace_logo.png',
    );
    expect(
      officialFeedSourceLogoAsset(OfficialFeedSources.toptoyUs),
      'assets/official_feed/toptoy_logo.png',
    );
    expect(
      officialFeedSourceLogoAsset(OfficialFeedSources.sonnyangelUs),
      'assets/official_feed/sonnyangel_logo.png',
    );
  });

  group('specificity and precedence', () {
    test('POP NOW from releaseType beats product path', () {
      expect(
        inferOfficialFeedContentTypeLabels(
          _item(
            title: 'THE MONSTERS — Have a Seat',
            summary: 'Vinyl plush — \$27.99',
            officialUrl:
                'https://www.popmart.com/us/pop-now/set/50-10009838800350',
            releaseType: 'pop_now',
          ),
        ),
        ['POP NOW'],
      );
    });

    test('store opening beats product path and announcement language', () {
      expect(
        inferOfficialFeedContentTypeLabels(
          _item(
            title: 'Grand opening this weekend',
            summary: 'Flagship store opening. Online May 1.',
            officialUrl: 'https://www.popmart.com/us/products/1/store-event',
          ),
        ),
        ['Store Opening'],
      );
    });

    test('restock from back in stock', () {
      expect(
        inferOfficialFeedContentTypeLabels(
          _item(
            title: 'Labubu restock notice',
            summary: 'Back in stock this Friday',
            officialUrl: 'https://www.popmart.com/us/blog/restock',
          ),
        ),
        ['Restock'],
      );
    });

    test('coming soon migrates former launch-reminder language', () {
      expect(
        inferOfficialFeedContentTypeLabels(
          _item(
            title: 'Mowdo teaser',
            summary: "Coming soon — don't miss it",
            officialUrl: 'https://www.instagram.com/p/DbSjwQwihMe/',
          ),
        ),
        ['Coming Soon'],
      );
    });

    test(
      'Campaign label is removed; collaboration wins on collab language',
      () {
        final tags = inferOfficialFeedContentTypeLabels(
          _item(
            title: 'Summer campaign collaboration collection',
            summary: 'Brand collab drop',
            officialUrl: 'https://www.popmart.com/us/blog/campaign',
          ),
        );
        expect(tags, isNot(contains('Campaign')));
        expect(tags, isNot(contains('Launch Reminder')));
        expect(tags.first, 'Collaboration');
      },
    );
  });

  group('two compatible specific tags', () {
    test('limited edition collaboration', () {
      expect(
        inferOfficialFeedContentTypeLabels(
          _item(
            title: 'SKULLPANDA × My Little Pony limited edition',
            summary: 'Limited edition crossover pendants',
            officialUrl: 'https://www.popmart.com/us/blog/collab',
          ),
        ),
        ['Limited Release', 'Collaboration'],
      );
    });

    test('store opening with giveaway', () {
      expect(
        inferOfficialFeedContentTypeLabels(
          _item(
            title: 'Grand opening giveaway',
            summary: 'Store opening contest this Saturday',
            officialUrl: 'https://www.popmart.com/us/blog/opening',
          ),
        ),
        ['Store Opening', 'Giveaway'],
      );
    });
  });

  test('returns at most two tags when more match', () {
    final tags = inferOfficialFeedContentTypeLabels(
      _item(
        title: 'Grand opening giveaway × collab limited edition pop-up',
        summary: 'Restock back in stock contest exhibition',
        officialUrl: 'https://www.popmart.com/us/blog/mega',
      ),
    );
    expect(tags.length, lessThanOrEqualTo(2));
    expect(tags, ['Store Opening', 'Restock']);
  });

  group('broad-tag suppression', () {
    test('does not pad Product Spotlight with Announcement', () {
      expect(
        inferOfficialFeedContentTypeLabels(
          _item(
            title: 'CRYBABY Cry Me an Ocean Series',
            summary: 'Vinyl plush pendants — online May 14, 7:00 PM PT',
            officialUrl:
                'https://www.popmart.com/us/products/6278/crybaby-cry-me-an-ocean',
            releaseType: 'product',
          ),
        ),
        ['Product Spotlight'],
      );
    });

    test('does not add Announcement beside Collaboration', () {
      expect(
        inferOfficialFeedContentTypeLabels(
          _item(
            title: 'SKULLPANDA × My Little Pony Series',
            summary: 'Plush doll pendants — online May 1',
            officialUrl:
                'https://www.popmart.com/us/products/6200/skullpanda-x-mlp',
          ),
        ),
        ['Collaboration'],
      );
    });

    test('does not add Official Update to fill a second slot', () {
      expect(
        inferOfficialFeedContentTypeLabels(
          _item(
            title: 'Back in stock tomorrow',
            summary: 'Restock notice',
            officialUrl: 'https://www.popmart.com/us/blog/restock',
          ),
        ),
        ['Restock'],
      );
    });
  });

  group('releaseType', () {
    test('missing releaseType still infers from copy and path', () {
      expect(
        inferOfficialFeedContentTypeLabels(
          _item(
            title: 'THE MONSTERS Exciting Macaron',
            summary: 'Tasty Macarons vinyl face blind box',
            officialUrl:
                'https://www.popmart.com/us/products/675/the-monsters-exciting-macaron',
          ),
        ),
        ['Product Spotlight'],
      );
    });

    test('unknown releaseType is ignored', () {
      expect(
        inferOfficialFeedContentTypeLabels(
          _item(
            title: 'Community note',
            summary: 'Read the latest blog post',
            officialUrl: 'https://www.popmart.com/us/blog/note',
            releaseType: 'mystery_box_drop',
          ),
        ),
        [OfficialFeedCopy.fallbackDeckLine],
      );
    });

    test('only pop_now is an explicit releaseType signal', () {
      expect(
        inferOfficialFeedContentTypeLabels(
          _item(
            title: 'Plain title',
            summary: 'No keywords',
            officialUrl: 'https://www.popmart.com/us/blog/x',
            releaseType: 'product',
          ),
        ),
        [OfficialFeedCopy.fallbackDeckLine],
      );
      expect(
        inferOfficialFeedContentTypeLabels(
          _item(
            title: 'Plain title',
            summary: 'No keywords',
            officialUrl: 'https://www.popmart.com/us/blog/x',
            releaseType: 'pop_now',
          ),
        ),
        ['POP NOW'],
      );
    });
  });

  group('all supported brands share the same rules', () {
    for (final brand in [
      (
        OfficialFeedSources.popmartUs,
        'POP MART',
        'https://www.popmart.com/us/products/1/x',
      ),
      (
        OfficialFeedSources.tntspaceUs,
        'TNT SPACE',
        'https://www.tntspace.com/products/1',
      ),
      (
        OfficialFeedSources.toptoyUs,
        'TOP TOY',
        'https://www.gotoptoy.com/products/1',
      ),
      (
        OfficialFeedSources.sonnyangelUs,
        'Sonny Angel',
        'https://www.sonnyangel.com/en/products/1',
      ),
    ]) {
      test('${brand.$2} product path → Product Spotlight', () {
        expect(
          inferOfficialFeedContentTypeLabels(
            _item(
              title: 'Series release',
              summary: 'New figures',
              officialUrl: brand.$3,
              sourceId: brand.$1,
              sourceLabel: brand.$2,
            ),
          ),
          ['Product Spotlight'],
        );
      });

      test('${brand.$2} coming soon language → Coming Soon', () {
        expect(
          inferOfficialFeedContentTypeLabels(
            _item(
              title: 'Teaser',
              summary: 'Coming soon',
              officialUrl: 'https://www.instagram.com/p/DbSjwQwihMe/',
              sourceId: brand.$1,
              sourceLabel: brand.$2,
            ),
          ),
          ['Coming Soon'],
        );
      });
    }
  });

  group('URL path matching', () {
    test('matches /products/ and /collections/ and /collection/', () {
      expect(
        inferOfficialFeedContentTypeLabels(
          _item(
            title: 'A',
            officialUrl: 'https://www.popmart.com/us/products/1/a',
          ),
        ),
        ['Product Spotlight'],
      );
      expect(
        inferOfficialFeedContentTypeLabels(
          _item(
            title: 'B',
            officialUrl: 'https://www.popmart.com/us/collections/labubu',
          ),
        ),
        ['Product Spotlight'],
      );
      expect(
        inferOfficialFeedContentTypeLabels(
          _item(
            title: 'C',
            officialUrl: 'https://www.popmart.com/us/collection/labubu',
          ),
        ),
        ['Product Spotlight'],
      );
    });

    test('pop-now path without releaseType', () {
      expect(
        inferOfficialFeedContentTypeLabels(
          _item(
            title: 'POP NOW set',
            officialUrl: 'https://www.popmart.com/us/pop-now/set/1',
          ),
        ),
        ['POP NOW'],
      );
    });
  });

  test('falls back to Official Update when no rule matches', () {
    expect(
      inferOfficialFeedContentTypeLabels(
        _item(
          title: 'POP MART community news',
          summary: 'Read the latest blog post',
          officialUrl: 'https://www.popmart.com/us/blog/some-post',
        ),
      ),
      [OfficialFeedCopy.fallbackDeckLine],
    );
    expect(OfficialFeedCopy.fallbackDeckLine, 'Official Update');
  });

  testWidgets('narrow-width label renders 1–2 pills without overflow', (
    tester,
  ) async {
    final twoTag = _item(
      title: 'Grand opening giveaway',
      summary: 'Store opening contest',
      officialUrl: 'https://www.popmart.com/us/blog/opening',
    );
    final oneTag = _item(
      title: 'Plain product',
      officialUrl: 'https://www.popmart.com/us/products/1/x',
    );

    for (final item in [twoTag, oneTag]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                child: OfficialFeedContentTypeLabel(item: item),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byType(OfficialFeedContentTypeLabel));
      expect(size.width, lessThanOrEqualTo(120.01));

      final labels = inferOfficialFeedContentTypeLabels(item);
      expect(labels.length, inInclusiveRange(1, 2));
      for (final label in labels) {
        expect(find.text(label), findsOneWidget);
      }
    }
  });
}
