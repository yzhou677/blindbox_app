import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_catalog.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_sources.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_content_type.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_copy.dart';
import 'package:blindbox_app/features/official_feed/widgets/official_feed_content_type_label.dart';
import 'package:blindbox_app/features/official_feed/widgets/official_feed_post_tile.dart';
import 'package:blindbox_app/features/official_feed/application/official_feed_providers.dart';
import 'package:blindbox_app/features/official_feed/widgets/official_feed_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

OfficialFeedItem _item({
  required String id,
  required String title,
  String? summary,
  required String officialUrl,
  String? instagramUrl,
  String sourceId = OfficialFeedSources.popmartUs,
  String sourceLabel = 'POP MART',
  DateTime? publishedAt,
}) {
  return OfficialFeedItem(
    id: id,
    sourceId: sourceId,
    sourceLabel: sourceLabel,
    title: title,
    summary: summary,
    imageUrl: 'https://cdn.example.com/$id.png',
    officialUrl: officialUrl,
    publishedAt: publishedAt ?? DateTime.utc(2026, 5, 18),
    contentHash: 'h_$id',
    instagramUrl: instagramUrl,
  );
}

Future<void> _pumpTile(
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfficialFeedCopy.destinationActionLabel', () {
    test('product URL uses View product', () {
      expect(
        OfficialFeedCopy.destinationActionLabel(
          'https://www.popmart.com/us/products/1/x',
        ),
        OfficialFeedCopy.viewProductAction,
      );
    });

    test('Instagram URL uses View post', () {
      expect(
        OfficialFeedCopy.destinationActionLabel(
          'https://www.instagram.com/p/Abc123/',
        ),
        OfficialFeedCopy.viewPostAction,
      );
    });
  });

  group('OfficialFeedPostTile layout', () {
    testWidgets('renders one inferred tag', (tester) async {
      final item = _item(
        id: 'one',
        title: 'Plain product',
        officialUrl: 'https://www.popmart.com/us/products/1/x',
      );
      final tags = inferOfficialFeedContentTypeLabels(item);
      expect(tags, hasLength(1));

      await _pumpTile(tester, item);
      expect(find.byKey(OfficialFeedContentTypeLabel.tagsRowKey), findsOneWidget);
      expect(find.text(tags.first), findsOneWidget);
    });

    testWidgets('renders two inferred tags on one row', (tester) async {
      final item = _item(
        id: 'two',
        title: 'Grand opening giveaway',
        summary: 'Store opening contest',
        officialUrl: 'https://www.popmart.com/us/blog/opening',
      );
      final tags = inferOfficialFeedContentTypeLabels(item);
      expect(tags, hasLength(2));

      await _pumpTile(tester, item);
      final tagsBox = tester.getRect(
        find.byKey(OfficialFeedContentTypeLabel.tagsRowKey),
      );
      for (final tag in tags) {
        expect(find.text(tag), findsOneWidget);
        final tagTop = tester.getTopLeft(find.text(tag)).dy;
        expect(tagTop, closeTo(tagsBox.top, 8));
      }
    });

    testWidgets('long title and summary truncate without overflow', (
      tester,
    ) async {
      final item = _item(
        id: 'long',
        title:
            'An extremely long official product title that should wrap once '
            'then ellipsize without overflowing the card frame',
        summary:
            'A lengthy summary that also needs two lines of calm deck copy '
            'without spilling past the thumbnail column or card edge.',
        officialUrl: 'https://www.popmart.com/us/products/99/long-name',
      );
      await _pumpTile(tester, item, width: 320);
      expect(tester.takeException(), isNull);

      final title = tester.widget<Text>(find.text(item.title));
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);

      final summary = tester.widget<Text>(find.text(item.summary!));
      expect(summary.maxLines, 2);
      expect(summary.overflow, TextOverflow.ellipsis);
    });

    testWidgets('missing product URL shows View post without host line', (
      tester,
    ) async {
      final item = _item(
        id: 'ig_only',
        title: 'Sonny Angel IG announcement',
        officialUrl: 'https://www.instagram.com/p/DYV-s76BUkQ/',
        sourceId: OfficialFeedSources.sonnyangelUs,
        sourceLabel: 'Sonny Angel',
      );
      await _pumpTile(tester, item);
      expect(find.text(OfficialFeedCopy.viewPostAction), findsOneWidget);
      expect(find.text(OfficialFeedCopy.viewProductAction), findsNothing);
      expect(find.textContaining('instagram.com'), findsNothing);
      expect(find.byKey(OfficialFeedPostTile.destinationKey), findsOneWidget);
    });

    testWidgets('via IG is clickable only for product + instagramUrl', (
      tester,
    ) async {
      await _pumpTile(
        tester,
        _item(
          id: 'no_ig',
          title: 'Product',
          officialUrl: 'https://www.popmart.com/us/products/1/x',
        ),
      );
      expect(
        find.text(OfficialFeedCopy.announcedOnInstagramPhrase),
        findsOneWidget,
      );
      expect(find.byKey(const Key('official_feed_via_ig')), findsNothing);

      await _pumpTile(
        tester,
        _item(
          id: 'with_ig',
          title: 'Product',
          officialUrl: 'https://www.popmart.com/us/products/1/x',
          instagramUrl: 'https://www.instagram.com/p/Abc123/',
        ),
      );
      expect(find.byKey(const Key('official_feed_via_ig')), findsOneWidget);

      const ig = 'https://www.instagram.com/p/Abc123/';
      await _pumpTile(
        tester,
        _item(
          id: 'ig_body',
          title: 'IG announcement',
          officialUrl: ig,
          instagramUrl: ig,
        ),
      );
      expect(
        find.text(OfficialFeedCopy.announcedOnInstagramPhrase),
        findsOneWidget,
      );
      expect(find.byKey(const Key('official_feed_via_ig')), findsNothing);
    });

    testWidgets('narrow width keeps metadata tags and CTA without overflow', (
      tester,
    ) async {
      final item = _item(
        id: 'narrow',
        title: 'Grand opening giveaway limited collaboration restock',
        summary: 'Store opening contest with giveaway details for collectors',
        officialUrl: 'https://www.popmart.com/us/blog/opening',
        instagramUrl: 'https://www.instagram.com/p/Abc123/',
      );
      await _pumpTile(tester, item, width: 300);
      expect(tester.takeException(), isNull);

      final cardSize = tester.getSize(find.byType(OfficialFeedPostTile));
      expect(cardSize.width, lessThanOrEqualTo(300.01));
      expect(
        find.text(OfficialFeedCopy.announcedOnInstagramPhrase),
        findsOneWidget,
      );
      expect(find.byKey(OfficialFeedPostTile.destinationKey), findsOneWidget);
      expect(find.byKey(OfficialFeedContentTypeLabel.tagsRowKey), findsOneWidget);

      final tagsSize = tester.getSize(
        find.byKey(OfficialFeedContentTypeLabel.tagsRowKey),
      );
      expect(tagsSize.width, lessThanOrEqualTo(cardSize.width));
    });
  });

  group('Official feed list bottom clearance', () {
    testWidgets('final card has dedicated list bottom padding', (tester) async {
      final items = [
        for (var i = 0; i < 2; i++)
          _item(
            id: 'pad_$i',
            title: 'Item $i',
            officialUrl: 'https://www.popmart.com/us/products/$i/x',
          ),
      ];
      final catalog = OfficialFeedCatalog({
        OfficialFeedSources.popmartUs: items,
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            officialFeedCatalogProvider.overrideWith((_) async => catalog),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: OfficialFeedSection(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tiles = find.byType(OfficialFeedPostTile);
      expect(tiles, findsNWidgets(2));
      final lastBottom = tester.getBottomLeft(tiles.last).dy;
      final sectionBottom = tester.getBottomLeft(find.byType(OfficialFeedSection)).dy;
      final clearance = sectionBottom - lastBottom;
      expect(
        clearance,
        greaterThanOrEqualTo(FeedRhythm.homeOfficialFeedListBottomPadding - 0.5),
      );
    });
  });
}
