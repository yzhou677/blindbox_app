import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_item.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_post_date.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_source_presenter.dart';
import 'package:blindbox_app/features/official_feed/utils/open_official_feed_url.dart';
import 'package:blindbox_app/features/official_feed/widgets/official_feed_thumbnail.dart';
import 'package:flutter/material.dart';

/// Compact official update row — bulletin style, not hero marketing.
class OfficialFeedPostTile extends StatelessWidget {
  const OfficialFeedPostTile({super.key, required this.item});

  final OfficialFeedItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final host = officialFeedHostLabel(item.officialUrl);
    final postDate = formatOfficialFeedPostDate(item.publishedAt);

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
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OfficialFeedSourceMark(sourceId: item.sourceId),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.sourceLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              Text(
                                ' · $postDate',
                                style: textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            officialFeedDeckLine(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.58,
                              ),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _OfficialBadge(),
                  ],
                ),
                const SizedBox(height: 10),
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
                            style: CollectibleTypography.catalogSeriesRowTitle(
                              textTheme,
                              scheme,
                            ).copyWith(height: 1.22),
                          ),
                          if (item.summary case final snippet?
                              when snippet.trim().isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              snippet.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: CollectibleTypography.catalogSeriesRowMeta(
                                textTheme,
                                scheme,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    OfficialFeedThumbnail(imageUrl: item.imageUrl),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 15,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Official post',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.62),
                      ),
                    ),
                    if (host.isNotEmpty) ...[
                      const Spacer(),
                      Text(
                        host,
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(
                            alpha: 0.42,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfficialBadge extends StatelessWidget {
  const _OfficialBadge();

  @override
  Widget build(BuildContext context) {
    const verifiedGreen = Color(0xFF2E9E62);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: verifiedGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: verifiedGreen.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 14, color: verifiedGreen),
            const SizedBox(width: 4),
            Text(
              'Official',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: verifiedGreen.withValues(alpha: 0.95),
                letterSpacing: 0.02,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
