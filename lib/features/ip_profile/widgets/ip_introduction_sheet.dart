import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/core/theme/shelfy_symbols.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:blindbox_app/features/ip_profile/domain/ip_introduction_profile.dart';
import 'package:blindbox_app/features/ip_profile/presentation/ip_introduction_ownership.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_sheet_chrome.dart';
import 'package:blindbox_app/shared/widgets/taxonomy_brand_chip_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Opens the compact IP introduction sheet (Discover Series detail).
Future<void> showIpIntroductionSheet({
  required BuildContext context,
  required IpIntroductionProfile profile,
  required SeriesRelease release,
}) {
  return showCollectibleBottomSheet<void>(
    context: context,
    wrapContentHeight: true,
    contentMaxHeightFraction: FeedRhythm.sheetMaxChildSize,
    builder: (context, scrollController) {
      return IpIntroductionSheet(
        profile: profile,
        release: release,
        scrollController: scrollController,
      );
    },
  );
}

/// Compact IP introduction body — name, tags, description, ownership, creator.
class IpIntroductionSheet extends ConsumerWidget {
  const IpIntroductionSheet({
    super.key,
    required this.profile,
    required this.release,
    required this.scrollController,
  });

  final IpIntroductionProfile profile;

  /// Discover Series context for the open sheet (not used for ownership scope).
  final SeriesRelease release;
  final ScrollController scrollController;

  static const double _horizontal = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final snapshot = ref.watch(collectionNotifierProvider);
    final ownership = resolveIpIntroductionIpSeriesCount(
      ipId: profile.ipId,
      snapshot: snapshot,
    );

    // ListView + shrinkWrap keeps wrap-content sheets short; avoid
    // Expanded/fill patterns that stretch the modal Material full-screen.
    return CollectibleSheetInsets(
      key: const Key('ip_introduction_sheet'),
      extraBottom: FeedRhythm.sheetBodyBottomInset,
      child: ListView(
        controller: scrollController,
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: _horizontal - 16),
        children: [
          Semantics(
            header: true,
            namesRoute: true,
            label: profile.displayName,
            child: const CollectibleSheetChrome(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              profile.displayName,
              key: const Key('ip_introduction_title'),
              style: CollectibleTypography.seriesHeroTitle(textTheme, scheme),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            key: const Key('ip_introduction_style_tags'),
            spacing: FeedRhythm.sheetControlGap,
            runSpacing: FeedRhythm.sheetControlGap,
            children: [
              for (final tag in profile.styleTags)
                IgnorePointer(
                  child: TaxonomyFilterPillChip(
                    label: tag,
                    selected: false,
                    compact: true,
                    emphasized: true,
                    horizontalPadding: 10,
                    onTap: () {},
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            profile.shortDescription,
            key: const Key('ip_introduction_short_description'),
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (ownership != null) ...[
            const SizedBox(height: AppSpacing.xl),
            Divider(
              key: const Key('ip_introduction_ownership_divider'),
              height: 1,
              thickness: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
            const SizedBox(height: AppSpacing.lg),
            _OwnershipRow(ownership: ownership),
          ],
          if (profile.hasCreator) ...[
            const SizedBox(height: AppSpacing.xl),
            Divider(
              height: 1,
              thickness: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
            const SizedBox(height: AppSpacing.lg),
            _CreatorSection(
              name: profile.creatorDisplayName!,
              bio: profile.creatorBio!,
            ),
          ],
        ],
      ),
    );
  }
}

class _OwnershipRow extends StatelessWidget {
  const _OwnershipRow({required this.ownership});

  final IpIntroductionIpSeriesCount ownership;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: 'In your collection, ${ownership.seriesLine}',
      child: Row(
        key: const Key('ip_introduction_ownership'),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Symbols.checklist_rounded,
              size: AppIconSizes.standard,
              color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IN YOUR COLLECTION',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  ownership.seriesLine,
                  key: const Key('ip_introduction_ownership_series_line'),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatorSection extends StatelessWidget {
  const _CreatorSection({required this.name, required this.bio});

  final String name;
  final String bio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return KeyedSubtree(
      key: const Key('ip_introduction_creator'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CREATED BY',
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            name,
            key: const Key('ip_introduction_creator_name'),
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            bio,
            key: const Key('ip_introduction_creator_bio'),
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
