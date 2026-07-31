import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';

/// Supported Official feed deck tags (display copy).
abstract final class OfficialFeedContentTags {
  OfficialFeedContentTags._();

  static const popNow = 'POP NOW';
  static const storeOpening = 'Store Opening';
  static const restock = 'Restock';
  static const giveaway = 'Giveaway';
  static const event = 'Event';
  static const limitedRelease = 'Limited Release';
  static const collaboration = 'Collaboration';
  static const comingSoon = 'Coming Soon';
  static const productSpotlight = 'Product Spotlight';
  static const announcement = 'Announcement';
  static const officialUpdate = 'Official Update';

  /// Lower rank = more specific / preferred.
  static const Map<String, int> specificityRank = {
    popNow: 0,
    storeOpening: 1,
    restock: 2,
    giveaway: 3,
    event: 4,
    limitedRelease: 5,
    collaboration: 6,
    comingSoon: 7,
    productSpotlight: 8,
    announcement: 9,
    officialUpdate: 10,
  };

  /// Path-derived or catch-all labels — never pad a more specific tag.
  static const Set<String> secondaryLabels = {
    productSpotlight,
    announcement,
    officialUpdate,
  };
}

/// Infers 1–2 deck tags for [item]. Fully automatic — no curator tag field.
///
/// Collects all matches, ranks by specificity, drops redundant secondary
/// labels when a more specific tag applies, and returns at most two tags.
List<String> inferOfficialFeedContentTypeLabels(OfficialFeedItem item) {
  final path = _normalizedPath(item.officialUrl);
  final hay = _haystack(item, path);
  final matched = <String>{};

  for (final rule in _rules) {
    if (rule.matches(item, path, hay)) {
      matched.add(rule.label);
    }
  }

  if (matched.isEmpty) {
    return const [OfficialFeedContentTags.officialUpdate];
  }

  final ranked = matched.toList()
    ..sort((a, b) {
      final ra =
          OfficialFeedContentTags.specificityRank[a] ??
          OfficialFeedContentTags.specificityRank.length;
      final rb =
          OfficialFeedContentTags.specificityRank[b] ??
          OfficialFeedContentTags.specificityRank.length;
      return ra.compareTo(rb);
    });

  final primary = ranked
      .where((t) => !OfficialFeedContentTags.secondaryLabels.contains(t))
      .toList();

  if (primary.isNotEmpty) {
    return List<String>.unmodifiable(primary.take(2));
  }

  // Only secondary matches: prefer Product Spotlight, else Announcement.
  if (ranked.contains(OfficialFeedContentTags.productSpotlight)) {
    return const [OfficialFeedContentTags.productSpotlight];
  }
  if (ranked.contains(OfficialFeedContentTags.announcement)) {
    return const [OfficialFeedContentTags.announcement];
  }
  return const [OfficialFeedContentTags.officialUpdate];
}

/// Primary (most specific) tag — convenience for style/tests.
String inferOfficialFeedContentTypeLabel(OfficialFeedItem item) {
  return inferOfficialFeedContentTypeLabels(item).first;
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

bool _isProductSpotlightPath(String path) {
  return path.contains('/products/') ||
      path.contains('/collections/') ||
      path.contains('/collection/');
}

final class _ContentTypeRule {
  const _ContentTypeRule(this.label, this.matches);

  final String label;
  final bool Function(OfficialFeedItem item, String path, String hay) matches;
}

/// Match collectors — order here is unrelated to display rank (see specificity).
final List<_ContentTypeRule> _rules = [
  _ContentTypeRule(
    OfficialFeedContentTags.popNow,
    (item, path, hay) =>
        item.releaseType == 'pop_now' || path.contains('/pop-now/'),
  ),
  _ContentTypeRule(
    OfficialFeedContentTags.giveaway,
    (_, _, hay) => _containsAny(hay, ['giveaway', 'contest', 'sweepstakes']),
  ),
  _ContentTypeRule(
    OfficialFeedContentTags.storeOpening,
    (_, _, hay) =>
        _containsAny(hay, ['store opening', 'grand opening', 'flagship store']),
  ),
  _ContentTypeRule(
    OfficialFeedContentTags.event,
    (_, _, hay) => _containsAny(hay, [
      'pop-up',
      'pop up',
      'popup',
      'exhibition',
      'fan fest',
      'convention',
    ]),
  ),
  _ContentTypeRule(
    OfficialFeedContentTags.restock,
    (_, _, hay) =>
        _containsAny(hay, ['restock', 'back in stock', 'available again']),
  ),
  _ContentTypeRule(OfficialFeedContentTags.collaboration, (item, _, hay) {
    final title = item.title.toLowerCase();
    return title.contains('×') ||
        title.contains(' x ') ||
        _containsAny(hay, ['collaboration', 'collab', 'crossover']);
  }),
  _ContentTypeRule(
    OfficialFeedContentTags.comingSoon,
    (_, _, hay) => _containsAny(hay, [
      'reminder',
      'last chance',
      'notify me',
      'coming soon',
      "don't miss",
    ]),
  ),
  _ContentTypeRule(
    OfficialFeedContentTags.limitedRelease,
    (_, _, hay) => _containsAny(hay, [
      'limited release',
      'limited edition',
      'exclusive drop',
    ]),
  ),
  _ContentTypeRule(
    OfficialFeedContentTags.announcement,
    (_, _, hay) => _containsAny(hay, [
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
    OfficialFeedContentTags.productSpotlight,
    (_, path, _) => _isProductSpotlightPath(path),
  ),
];
