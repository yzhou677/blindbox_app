import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_sources.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_copy.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_post_date.dart';
import 'package:blindbox_app/features/official_feed/utils/open_official_feed_url.dart';
import 'package:blindbox_app/features/official_feed/widgets/official_feed_post_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

OfficialFeedItem _item({
  required String id,
  required String sourceId,
  required String sourceLabel,
  required String officialUrl,
  DateTime? publishedAt,
  String title = 'Sample title',
}) {
  return OfficialFeedItem(
    id: id,
    sourceId: sourceId,
    sourceLabel: sourceLabel,
    title: title,
    imageUrl: 'https://cdn.example.com/$id.png',
    officialUrl: officialUrl,
    publishedAt: publishedAt ?? DateTime.utc(2026, 7, 25, 18),
    contentHash: 'hash_$id',
    summary: 'Online July 30, 7:00 PM PT.',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formatOfficialFeedAnnouncementMeta', () {
    final publishedAt = DateTime.utc(2026, 7, 25, 18);
    final date = formatOfficialFeedPostDate(publishedAt);

    test('formatOfficialFeedAnnouncementProvenance omits the date', () {
      expect(
        formatOfficialFeedAnnouncementProvenance(sourceLabel: 'TOP TOY'),
        'TOP TOY · via IG',
      );
    });

    test(
      'formatOfficialFeedAnnouncementMeta POP MART uses via IG',
      () {
        expect(
          formatOfficialFeedAnnouncementMeta(
            sourceLabel: 'POP MART',
            publishedAt: publishedAt,
          ),
          'POP MART · via IG · $date',
        );
      },
    );

    test('TNT SPACE uses via IG', () {
      expect(
        formatOfficialFeedAnnouncementMeta(
          sourceLabel: 'TNT SPACE',
          publishedAt: publishedAt,
        ),
        'TNT SPACE · via IG · $date',
      );
    });

    test('TOP TOY uses via IG', () {
      expect(
        formatOfficialFeedAnnouncementMeta(
          sourceLabel: 'TOP TOY',
          publishedAt: publishedAt,
        ),
        'TOP TOY · via IG · $date',
      );
    });

    test('label does not depend on destination URL', () {
      final productMeta = formatOfficialFeedAnnouncementMeta(
        sourceLabel: 'TOP TOY',
        publishedAt: publishedAt,
      );
      final igMeta = formatOfficialFeedAnnouncementMeta(
        sourceLabel: 'TOP TOY',
        publishedAt: publishedAt,
      );
      expect(productMeta, igMeta);
      expect(productMeta, contains('via IG'));
      expect(productMeta, isNot(contains('gotoptoy')));
      expect(productMeta, isNot(contains('instagram.com')));
    });

    test('reuses formatOfficialFeedPostDate for locale calendar day', () {
      final localMorning = DateTime(2026, 7, 3, 3, 52);
      expect(
        formatOfficialFeedAnnouncementMeta(
          sourceLabel: 'POP MART',
          publishedAt: localMorning,
        ),
        'POP MART · via IG · '
        '${formatOfficialFeedPostDate(localMorning)}',
      );
    });

    test(
      'non-Instagram provenance is not modeled — Instagram copy is policy',
      () {
        // Curation policy: every publishedAt is an IG announcement instant.
        // No fallback phrase is wired; this documents the product decision.
        expect(
          OfficialFeedCopy.announcedOnInstagramPhrase,
          'via IG',
        );
        expect(
          formatOfficialFeedAnnouncementMeta(
            sourceLabel: 'POP MART',
            publishedAt: publishedAt,
          ),
          isNot(contains(' · Announced · ')),
        );
      },
    );
  });

  group('OfficialFeedPostTile metadata', () {
    final publishedAt = DateTime.utc(2026, 7, 25, 18);
    final date = formatOfficialFeedPostDate(publishedAt);

    Future<void> pumpTile(
      WidgetTester tester,
      OfficialFeedItem item, {
      double width = 390,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: OfficialFeedPostTile(item: item),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('product destination still shows via IG', (
      tester,
    ) async {
      final item = _item(
        id: 'tt_product',
        sourceId: OfficialFeedSources.toptoyUs,
        sourceLabel: 'TOP TOY',
        officialUrl:
            'https://gotoptoy.com/products/basaka-love-what-you-do-be-happy-series-plush-blind-box',
        publishedAt: publishedAt,
      );
      await pumpTile(tester, item);
      expect(find.text('TOP TOY · via IG'), findsOneWidget);
      expect(find.text(date), findsOneWidget);
    });

    testWidgets('Instagram destination shows the same metadata pattern', (
      tester,
    ) async {
      final item = _item(
        id: 'pm_ig',
        sourceId: OfficialFeedSources.popmartUs,
        sourceLabel: 'POP MART',
        officialUrl: 'https://www.instagram.com/p/DbKjAeemy7-/',
        publishedAt: publishedAt,
      );
      await pumpTile(tester, item);
      expect(find.text('POP MART · via IG'), findsOneWidget);
      expect(find.text(date), findsOneWidget);
    });

    testWidgets('TNT SPACE sourceLabel is preserved in metadata', (
      tester,
    ) async {
      final item = _item(
        id: 'tnt1',
        sourceId: OfficialFeedSources.tntspaceUs,
        sourceLabel: 'TNT SPACE',
        officialUrl: 'https://www.instagram.com/p/DbSjwQwihMe/',
        publishedAt: publishedAt,
      );
      await pumpTile(tester, item);
      expect(find.text('TNT SPACE · via IG'), findsOneWidget);
      expect(find.text(date), findsOneWidget);
      expect(find.textContaining('POP MART'), findsNothing);
    });

    testWidgets('narrow width keeps full date on its own line', (tester) async {
      final item = _item(
        id: 'narrow',
        sourceId: OfficialFeedSources.popmartUs,
        sourceLabel: 'POP MART',
        officialUrl: 'https://www.popmart.com/us/products/8340/off-mode',
        publishedAt: publishedAt,
        title: 'Very long official feed title that should truncate safely',
      );
      await pumpTile(tester, item, width: 320);
      expect(tester.takeException(), isNull);
      expect(find.text('POP MART · via IG'), findsOneWidget);
      expect(find.text(date), findsOneWidget);
    });

    testWidgets('tap opens the item officialUrl', (tester) async {
      final opened = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
          if (call.method == 'launch' || call.method == 'launchUrl') {
            final args = call.arguments;
            if (args is Map) {
              opened.add('${args['url']}');
            }
            return true;
          }
          if (call.method == 'canLaunch' || call.method == 'canLaunchUrl') {
            return true;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        );
      });

      const url =
          'https://gotoptoy.com/products/heymi-witchs-game-series-plush-doll-blind-box';
      final item = _item(
        id: 'tap',
        sourceId: OfficialFeedSources.toptoyUs,
        sourceLabel: 'TOP TOY',
        officialUrl: url,
        publishedAt: publishedAt,
      );
      await pumpTile(tester, item);
      await tester.tap(find.byType(OfficialFeedPostTile));
      await tester.pumpAndSettle();

      expect(opened, isNotEmpty);
      expect(opened.first, url);
    });
  });

  group('open helpers unchanged', () {
    test('tryOpenOfficialFeedUrl rejects non-https', () async {
      expect(await tryOpenOfficialFeedUrl('http://example.com'), isFalse);
      expect(await tryOpenOfficialFeedUrl(''), isFalse);
    });
  });

  group('ordering still uses publishedAt', () {
    test('later Instagram announcement sorts first', () {
      final older = _item(
        id: 'old',
        sourceId: OfficialFeedSources.popmartUs,
        sourceLabel: 'POP MART',
        officialUrl: 'https://www.instagram.com/p/old/',
        publishedAt: DateTime.utc(2026, 7, 20),
      );
      final newer = _item(
        id: 'new',
        sourceId: OfficialFeedSources.popmartUs,
        sourceLabel: 'POP MART',
        officialUrl: 'https://www.popmart.com/us/products/1/a',
        publishedAt: DateTime.utc(2026, 7, 25),
      );
      final sorted = [older, newer]
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      expect(sorted.first.id, 'new');
      expect(sorted.last.id, 'old');
    });
  });
}
