import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/official_feed/data/official_feed_mapper.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_sources.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_copy.dart';
import 'package:blindbox_app/features/official_feed/widgets/official_feed_post_tile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

OfficialFeedItem _item({required String officialUrl, String? instagramUrl}) {
  return OfficialFeedItem(
    id: 'x',
    sourceId: OfficialFeedSources.popmartUs,
    sourceLabel: 'POP MART',
    title: 'Title',
    imageUrl: 'https://cdn.example.com/a.png',
    officialUrl: officialUrl,
    publishedAt: DateTime.utc(2026, 5, 18),
    contentHash: 'h',
    instagramUrl: instagramUrl,
  );
}

Map<String, dynamic> _doc({
  required String officialUrl,
  Object? instagramUrl = _absent,
  String sourceId = OfficialFeedSources.popmartUs,
  String sourceLabel = 'POP MART',
}) {
  final map = <String, dynamic>{
    'id': 'doc',
    'sourceId': sourceId,
    'sourceLabel': sourceLabel,
    'title': 'Title',
    'imageUrl': 'https://cdn.example.com/a.png',
    'officialUrl': officialUrl,
    'publishedAt': Timestamp.fromDate(DateTime.utc(2026, 5, 18)),
    'status': 'active',
    'contentHash': 'h',
  };
  if (!identical(instagramUrl, _absent)) {
    map['instagramUrl'] = instagramUrl;
  }
  return map;
}

const _absent = Object();

void main() {
  group('parseOfficialFeedInstagramUrl', () {
    test('accepts /p /reel /tv https Instagram posts', () {
      expect(
        parseOfficialFeedInstagramUrl('https://www.instagram.com/p/Abc123/'),
        'https://www.instagram.com/p/Abc123/',
      );
      expect(
        parseOfficialFeedInstagramUrl('https://instagram.com/reel/Abc123'),
        isNotNull,
      );
      expect(
        parseOfficialFeedInstagramUrl('https://www.instagram.com/tv/Abc123/'),
        isNotNull,
      );
    });

    test('rejects missing invalid and non-post paths', () {
      expect(parseOfficialFeedInstagramUrl(null), isNull);
      expect(parseOfficialFeedInstagramUrl(''), isNull);
      expect(
        parseOfficialFeedInstagramUrl('http://www.instagram.com/p/x/'),
        isNull,
      );
      expect(
        parseOfficialFeedInstagramUrl('https://www.instagram.com/sonnyangel/'),
        isNull,
      );
      expect(
        parseOfficialFeedInstagramUrl(
          'https://www.popmart.com/us/products/1/a',
        ),
        isNull,
      );
    });
  });

  group('mapOfficialFeedItem instagramUrl', () {
    test('preserves optional instagramUrl when valid', () {
      final item = mapOfficialFeedItem(
        'doc',
        _doc(
          officialUrl:
              'https://www.popmart.com/us/products/8339/SKULLPANDA-Off-Mode',
          instagramUrl: 'https://www.instagram.com/p/DbKjAeemy7-/',
        ),
      );
      expect(item, isNotNull);
      expect(item!.instagramUrl, 'https://www.instagram.com/p/DbKjAeemy7-/');
      expect(
        item.officialUrl,
        'https://www.popmart.com/us/products/8339/SKULLPANDA-Off-Mode',
      );
    });

    test('missing instagramUrl stays null (backward compatible)', () {
      final item = mapOfficialFeedItem(
        'doc',
        _doc(officialUrl: 'https://www.instagram.com/p/DbKjAeemy7-/'),
      );
      expect(item, isNotNull);
      expect(item!.instagramUrl, isNull);
    });

    test('invalid instagramUrl is ignored without rejecting the item', () {
      final item = mapOfficialFeedItem(
        'doc',
        _doc(
          officialUrl: 'https://www.instagram.com/p/DbKjAeemy7-/',
          instagramUrl: 'https://www.popmart.com/us/products/1/x',
        ),
      );
      expect(item, isNotNull);
      expect(item!.instagramUrl, isNull);
    });

    test('identical officialUrl and instagramUrl both map', () {
      const ig = 'https://www.instagram.com/p/DYV-s76BUkQ/';
      final item = mapOfficialFeedItem(
        'doc',
        _doc(
          officialUrl: ig,
          instagramUrl: ig,
          sourceId: OfficialFeedSources.sonnyangelUs,
          sourceLabel: 'Sonny Angel',
        ),
      );
      expect(item!.officialUrl, ig);
      expect(item.instagramUrl, ig);
    });
  });

  group('officialFeedViaIgIsTappable', () {
    test('product destination + instagramUrl is tappable', () {
      expect(
        officialFeedViaIgIsTappable(
          officialUrl: 'https://www.popmart.com/us/products/8339/x',
          instagramUrl: 'https://www.instagram.com/p/Abc123/',
        ),
        isTrue,
      );
    });

    test('product destination without instagramUrl is not tappable', () {
      expect(
        officialFeedViaIgIsTappable(
          officialUrl: 'https://www.popmart.com/us/products/8339/x',
          instagramUrl: null,
        ),
        isFalse,
      );
    });

    test('Instagram destination disables via IG even with instagramUrl', () {
      const ig = 'https://www.instagram.com/p/Abc123/';
      expect(
        officialFeedViaIgIsTappable(officialUrl: ig, instagramUrl: ig),
        isFalse,
      );
    });
  });

  group('OfficialFeedPostTile via IG', () {
    testWidgets('via IG is present with and without instagramUrl', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: OfficialFeedPostTile(
              item: _item(
                officialUrl:
                    'https://www.popmart.com/us/products/8339/SKULLPANDA',
              ),
            ),
          ),
        ),
      );
      expect(
        find.text(OfficialFeedCopy.announcedOnInstagramPhrase),
        findsOneWidget,
      );
      expect(find.textContaining('POP MART'), findsWidgets);
      expect(find.byKey(const Key('official_feed_via_ig')), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: OfficialFeedPostTile(
              item: _item(
                officialUrl:
                    'https://www.popmart.com/us/products/8339/SKULLPANDA',
                instagramUrl: 'https://www.instagram.com/p/Abc123/',
              ),
            ),
          ),
        ),
      );
      expect(
        find.text(OfficialFeedCopy.announcedOnInstagramPhrase),
        findsOneWidget,
      );
      expect(find.byKey(const Key('official_feed_via_ig')), findsOneWidget);
    });

    testWidgets('via IG is not clickable when card opens Instagram', (
      tester,
    ) async {
      const ig = 'https://www.instagram.com/p/Abc123/';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: OfficialFeedPostTile(
              item: _item(officialUrl: ig, instagramUrl: ig),
            ),
          ),
        ),
      );
      expect(
        find.text(OfficialFeedCopy.announcedOnInstagramPhrase),
        findsOneWidget,
      );
      expect(find.byKey(const Key('official_feed_via_ig')), findsNothing);
    });

    testWidgets('via IG remains visible at compact card width', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: OfficialFeedPostTile(
                  item: _item(
                    officialUrl:
                        'https://www.popmart.com/us/products/8339/SKULLPANDA',
                    instagramUrl: 'https://www.instagram.com/p/Abc123/',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text(OfficialFeedCopy.announcedOnInstagramPhrase),
        findsOneWidget,
      );
      expect(find.byKey(const Key('official_feed_via_ig')), findsOneWidget);
    });
  });
}
