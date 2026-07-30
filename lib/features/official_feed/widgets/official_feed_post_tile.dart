import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_copy.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_post_date.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_source_presenter.dart';
import 'package:blindbox_app/features/official_feed/utils/open_official_feed_url.dart';
import 'package:blindbox_app/features/official_feed/widgets/official_feed_content_type_label.dart';
import 'package:blindbox_app/features/official_feed/widgets/official_feed_thumbnail.dart';
import 'package:flutter/material.dart';

/// Compact official update row — bulletin style, not hero marketing.
///
/// Hierarchy: metadata → tags → title/summary + thumb → destination CTA.
class OfficialFeedPostTile extends StatelessWidget {
  const OfficialFeedPostTile({super.key, required this.item});

  final OfficialFeedItem item;

  static const destinationKey = Key('official_feed_destination');
  static const dateKey = Key('official_feed_announcement_date');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final provenanceStyle = textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
    );
    final dateStyle = textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w500,
      color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
    );

    return Material(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.cardRadius,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.22 : 0.34),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label: '${item.title}. Official post. Opens in browser.',
        child: InkWell(
          onTap: () => openOfficialFeedUrl(context, item.officialUrl),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FeedRhythm.homeOfficialFeedCardPaddingH,
              vertical: FeedRhythm.homeOfficialFeedCardPaddingV,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Metadata: logo · brand · via IG · date
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    OfficialFeedSourceMark(sourceId: item.sourceId),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ProvenanceLine(
                        sourceLabel: item.sourceLabel,
                        officialUrl: item.officialUrl,
                        instagramUrl: item.instagramUrl,
                        style: provenanceStyle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatOfficialFeedPostDate(item.publishedAt),
                      key: dateKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: dateStyle,
                    ),
                  ],
                ),
                const SizedBox(height: FeedRhythm.homeOfficialFeedCardMetaToTagsGap),
                // 2. Tags on their own row
                OfficialFeedContentTypeLabel(item: item),
                const SizedBox(height: FeedRhythm.homeOfficialFeedCardSectionGap),
                // 3. Title / summary + thumbnail
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                            style: CollectibleTypography.catalogSeriesRowTitle(
                              textTheme,
                              scheme,
                            ).copyWith(height: 1.25),
                          ),
                          if (item.summary case final snippet?
                              when snippet.trim().isNotEmpty) ...[
                            const SizedBox(
                              height:
                                  FeedRhythm.homeOfficialFeedCardTitleToSummaryGap,
                            ),
                            Text(
                              snippet.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                              style: CollectibleTypography.catalogSeriesRowMeta(
                                textTheme,
                                scheme,
                              ).copyWith(height: 1.3),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OfficialFeedThumbnail(
                      imageUrl: item.imageUrl,
                      sourceId: item.sourceId,
                    ),
                  ],
                ),
                const SizedBox(height: FeedRhythm.homeOfficialFeedCardSectionGap),
                // 4. Single destination CTA (no raw host line)
                Text(
                  OfficialFeedCopy.destinationActionLabel(item.officialUrl),
                  key: destinationKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `{sourceLabel} · via IG` — tappable only for product destinations with a
/// separate [instagramUrl] (disabled when the card body already opens IG).
class _ProvenanceLine extends StatelessWidget {
  const _ProvenanceLine({
    required this.sourceLabel,
    required this.officialUrl,
    required this.instagramUrl,
    required this.style,
  });

  final String sourceLabel;
  final String officialUrl;
  final String? instagramUrl;
  final TextStyle? style;

  static const viaIgKey = Key('official_feed_via_ig');

  @override
  Widget build(BuildContext context) {
    final viaIg = OfficialFeedCopy.announcedOnInstagramPhrase;
    final igUrl = instagramUrl?.trim();
    final canOpenIg = officialFeedViaIgIsTappable(
      officialUrl: officialUrl,
      instagramUrl: igUrl,
    );

    final viaIgText = Text(
      viaIg,
      maxLines: 1,
      style: canOpenIg
          ? style?.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: style?.color?.withValues(alpha: 0.45),
            )
          : style,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$sourceLabel · ', maxLines: 1, style: style),
            if (canOpenIg)
              Semantics(
                button: true,
                label: 'Open Instagram announcement',
                child: InkWell(
                  key: viaIgKey,
                  onTap: () => openOfficialFeedUrl(context, igUrl!),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    child: viaIgText,
                  ),
                ),
              )
            else
              viaIgText,
          ],
        ),
      ),
    );
  }
}
