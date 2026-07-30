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
  /// Short form so the card header fits beside the Official badge.
  static const String announcedOnInstagramPhrase = 'via IG';

  /// Per-card deck when heuristics do not match a content type.
  static const String fallbackDeckLine = 'Official Update';
}

/// Card header metadata: provenance of [publishedAt], not click destination.
///
/// Curation policy: every Official feed [publishedAt] is the corresponding
/// official Instagram announcement instant, so the Instagram phrase is always
/// used. Destination ([officialUrl]) may still be a product page.
///
/// UI shows this as two lines (provenance, then date) so the date is never
/// clipped by the Official badge.
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
