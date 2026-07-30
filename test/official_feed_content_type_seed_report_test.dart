import 'dart:convert';
import 'dart:io';

import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_content_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// Previous first-match-wins inference (frozen for seed before/after report).
String _legacyInfer(OfficialFeedItem item) {
  final path = (Uri.tryParse(item.officialUrl.trim())?.path ?? '')
      .toLowerCase();
  final hay = '${item.title} ${item.summary ?? ''} $path ${item.officialUrl}'
      .toLowerCase();

  bool containsAny(List<String> needles) {
    for (final n in needles) {
      if (hay.contains(n)) return true;
    }
    return false;
  }

  if (item.releaseType == 'pop_now' || path.contains('/pop-now/')) {
    return 'POP NOW';
  }
  if (containsAny(['giveaway', 'contest', 'sweepstakes'])) return 'Giveaway';
  if (containsAny(['store opening', 'grand opening', 'flagship store'])) {
    return 'Store Opening';
  }
  if (containsAny([
    'pop-up',
    'pop up',
    'popup',
    'exhibition',
    'fan fest',
    'convention',
  ])) {
    return 'Event';
  }
  if (containsAny(['restock', 'back in stock', 'available again'])) {
    return 'Restock';
  }
  final title = item.title.toLowerCase();
  if (title.contains('×') ||
      title.contains(' x ') ||
      containsAny(['collaboration', 'collab', 'crossover'])) {
    return 'Collaboration';
  }
  if (containsAny(['campaign', 'collaboration collection'])) return 'Campaign';
  if (containsAny([
    'reminder',
    'last chance',
    'notify me',
    'coming soon',
    "don't miss",
  ])) {
    return 'Launch Reminder';
  }
  if (containsAny(['limited release', 'limited edition', 'exclusive drop'])) {
    return 'Limited Release';
  }
  if (containsAny([
    'launch project',
    'online release',
    ' online ',
    ' drops ',
    'drop on',
    'pre-order',
    'preorder',
    'announcement',
    'launching',
    'release date',
    'available on',
  ])) {
    return 'Announcement';
  }
  if (path.contains('/products/') || path.contains('/collection/')) {
    return 'Product Spotlight';
  }
  return 'Official update';
}

String _matchedRuleHint(OfficialFeedItem item, List<String> tags) {
  final path = (Uri.tryParse(item.officialUrl.trim())?.path ?? '')
      .toLowerCase();
  final parts = <String>[];
  for (final tag in tags) {
    switch (tag) {
      case 'POP NOW':
        parts.add(
          item.releaseType == 'pop_now'
              ? 'releaseType=pop_now'
              : 'path /pop-now/',
        );
      case 'Coming Soon':
        parts.add('coming-soon/reminder language');
      case 'Product Spotlight':
        parts.add('path products|collections|collection');
      case 'Collaboration':
        parts.add('× / collab language');
      case 'Announcement':
        parts.add('announcement/online language');
      case 'Official Update':
        parts.add('no match fallback');
      default:
        parts.add(tag.toLowerCase());
    }
  }
  if (path.isNotEmpty) parts.add('path=$path');
  return parts.join('; ');
}

void main() {
  test('seed before/after tag report (print-only)', () {
    final seeds = [
      'tools/official_feed/popmart_us.seed.json',
      'tools/official_feed/tntspace_us.seed.json',
      'tools/official_feed/toptoy_us.seed.json',
    ];

    final rows = <String>[];
    for (final path in seeds) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: path);
      final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final sourceId = root['sourceId'] as String;
      final sourceLabel = root['sourceLabel'] as String;
      final items = root['items'] as List<dynamic>;
      for (final raw in items) {
        final m = raw as Map<String, dynamic>;
        if ((m['status'] as String?) != 'active') continue;
        final item = OfficialFeedItem(
          id: m['id'] as String,
          sourceId: sourceId,
          sourceLabel: sourceLabel,
          title: m['title'] as String,
          imageUrl: m['imageUrl'] as String? ?? '',
          officialUrl: m['officialUrl'] as String,
          publishedAt: DateTime.parse(m['publishedAt'] as String),
          contentHash: 'seed',
          summary: m['summary'] as String?,
          releaseType: m['releaseType'] as String?,
        );
        final oldTag = _legacyInfer(item);
        final newTags = inferOfficialFeedContentTypeLabels(item);
        final newJoined = newTags.join(' + ');
        if (oldTag != newJoined) {
          rows.add(
            '| ${item.id} | ${item.title} | $oldTag | $newJoined | '
            '${_matchedRuleHint(item, newTags)} |',
          );
        }
      }
    }

    // ignore: avoid_print
    print('\n## Seed tag before/after (${rows.length} changed)\n');
    // ignore: avoid_print
    print('| ID | Title | Old | New | Matched rule |');
    // ignore: avoid_print
    print('|---|---|---|---|---|');
    for (final row in rows) {
      // ignore: avoid_print
      print(row);
    }

    // Report-only: empty is fine when seeds are already aligned.
    expect(true, isTrue);
  });
}
