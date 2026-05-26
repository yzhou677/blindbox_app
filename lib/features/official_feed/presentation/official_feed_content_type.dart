import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_copy.dart';

/// Lightweight deck label for one official post (keyword heuristics only).
String inferOfficialFeedContentTypeLabel(OfficialFeedItem item) {
  final path = _normalizedPath(item.officialUrl);
  final hay = _haystack(item, path);

  for (final rule in _rules) {
    if (rule.matches(item, path, hay)) {
      return rule.label;
    }
  }
  return OfficialFeedCopy.fallbackDeckLine;
}

String _normalizedPath(String officialUrl) {
  final path = Uri.tryParse(officialUrl.trim())?.path ?? '';
  return path.toLowerCase();
}

String _haystack(OfficialFeedItem item, String path) {
  return '${item.title} ${item.summary ?? ''} $path ${item.officialUrl}'
      .toLowerCase();
}

bool _containsAny(String hay, List<String> needles) {
  for (final n in needles) {
    if (hay.contains(n)) return true;
  }
  return false;
}

final class _ContentTypeRule {
  const _ContentTypeRule(this.label, this.matches);

  final String label;
  final bool Function(OfficialFeedItem item, String path, String hay) matches;
}

/// First match wins — most specific rules first.
final List<_ContentTypeRule> _rules = [
  _ContentTypeRule(
    'POP NOW',
    (item, path, hay) =>
        item.releaseType == 'pop_now' || path.contains('/pop-now/'),
  ),
  _ContentTypeRule(
    'Giveaway',
    (_, __, hay) => _containsAny(hay, ['giveaway', 'contest', 'sweepstakes']),
  ),
  _ContentTypeRule(
    'Store Opening',
    (_, __, hay) =>
        _containsAny(hay, ['store opening', 'grand opening', 'flagship store']),
  ),
  _ContentTypeRule(
    'Event',
    (_, __, hay) => _containsAny(hay, [
      'pop-up',
      'pop up',
      'popup',
      'exhibition',
      'fan fest',
      'convention',
    ]),
  ),
  _ContentTypeRule(
    'Restock',
    (_, __, hay) =>
        _containsAny(hay, ['restock', 'back in stock', 'available again']),
  ),
  _ContentTypeRule(
    'Collaboration',
    (item, _, hay) {
      final title = item.title.toLowerCase();
      return title.contains('×') ||
          title.contains(' x ') ||
          _containsAny(hay, ['collaboration', 'collab', 'crossover']);
    },
  ),
  _ContentTypeRule(
    'Campaign',
    (_, __, hay) => _containsAny(hay, ['campaign', 'collaboration collection']),
  ),
  _ContentTypeRule(
    'Launch Reminder',
    (_, __, hay) => _containsAny(hay, [
      'reminder',
      'last chance',
      'notify me',
      'coming soon',
      'don\'t miss',
    ]),
  ),
  _ContentTypeRule(
    'Limited Release',
    (_, __, hay) => _containsAny(hay, [
      'limited release',
      'limited edition',
      'exclusive drop',
    ]),
  ),
  _ContentTypeRule(
    'Announcement',
    (_, __, hay) => _containsAny(hay, [
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
    ]),
  ),
  _ContentTypeRule(
    'Product Spotlight',
    (_, path, __) =>
        path.contains('/products/') || path.contains('/collection/'),
  ),
];
