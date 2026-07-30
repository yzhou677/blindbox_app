import 'package:blindbox_app/features/official_feed/domain/official_feed_sources.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_post_date.dart';

/// Home Official feeds section — news/announcement layer copy.
abstract final class OfficialFeedCopy {
  OfficialFeedCopy._();

  static const String sectionTitle = 'Official feeds';

  /// Used only as a fallback before a source is resolved.
  static const String sectionSubtitle = 'News, campaigns, and storefront links';

  static String sectionSubtitleFor(String sourceId) {
    final brand = OfficialFeedSources.displayLabel(sourceId);
    return 'News, campaigns, and links from $brand';
  }

  static const String releaseDateDisclosure =
      'Release dates may vary by region.';

  /// Provenance phrase for [publishedAt] (always Instagram by curation policy).
  /// Short form so the card header fits on one metadata row.
  static const String announcedOnInstagramPhrase = 'via IG';

  /// Per-card deck when heuristics do not match a content type.
  static const String fallbackDeckLine = 'Official Update';

  /// Footer CTA when [OfficialFeedItem.officialUrl] is a storefront/product page.
  static const String viewProductAction = 'View product ↗';

  /// Footer CTA when the only destination is an Instagram post.
  static const String viewPostAction = 'View post ↗';

  /// Concise destination label for the card footer (no raw host line).
  static String destinationActionLabel(String officialUrl) {
    if (officialFeedDestinationIsInstagram(officialUrl)) {
      return viewPostAction;
    }
    return viewProductAction;
  }
}

/// True when the card body destination is already an Instagram URL.
bool officialFeedDestinationIsInstagram(String officialUrl) {
  final host = (Uri.tryParse(officialUrl.trim())?.host ?? '').toLowerCase();
  return host == 'instagram.com' || host.endsWith('.instagram.com');
}

/// `via IG` is tappable only when the card opens a non-IG destination and a
/// separate provenance [instagramUrl] is available.
bool officialFeedViaIgIsTappable({
  required String officialUrl,
  required String? instagramUrl,
}) {
  final ig = instagramUrl?.trim();
  if (ig == null || ig.isEmpty) return false;
  return !officialFeedDestinationIsInstagram(officialUrl);
}

/// Card header metadata: provenance of [publishedAt].
///
/// Curation policy: every Official feed [publishedAt] is the corresponding
/// official Instagram announcement instant, so the Instagram phrase is always
/// shown. When [officialFeedViaIgIsTappable] is true, `via IG` opens
/// [OfficialFeedItem.instagramUrl]; the card body still opens
/// [OfficialFeedItem.officialUrl]. When the body already opens Instagram,
/// `via IG` stays visible but not tappable.
///
/// UI shows provenance and date on one metadata row.
String formatOfficialFeedAnnouncementMeta({
  required String sourceLabel,
  required DateTime publishedAt,
}) {
  return '${formatOfficialFeedAnnouncementProvenance(sourceLabel: sourceLabel)}'
      ' · ${formatOfficialFeedPostDate(publishedAt)}';
}

/// First metadata line: brand + Instagram provenance (no date).
String formatOfficialFeedAnnouncementProvenance({required String sourceLabel}) {
  return '$sourceLabel · ${OfficialFeedCopy.announcedOnInstagramPhrase}';
}
