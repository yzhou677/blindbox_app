import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/features/market/application/market_browse_notifier.dart';
import 'package:blindbox_app/features/market/application/market_live_browse_controller.dart';
import 'package:blindbox_app/features/market/application/market_live_browse_session.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while a new browse session is loading — not pagination [loadMore].
bool marketBrowseSessionTransitionActive(
  MarketBrowseState browse,
  MarketLiveBrowseState live, {
  bool? gatewayActive,
}) {
  if (!(gatewayActive ?? MarketGatewayConfig.isActive)) return false;
  if (live.isLoadingInitial || live.isRefreshing) return true;
  final uiQuery = marketBrowseQueryFromUi(browse);
  return uiQuery.signature != live.querySignature;
}

final marketBrowseSessionTransitionProvider = Provider<bool>((ref) {
  final browse = ref.watch(marketBrowseNotifierProvider);
  final live = ref.watch(marketLiveBrowseControllerProvider);
  return marketBrowseSessionTransitionActive(browse, live);
});

/// Dims stale rows and shows a lightweight spinner during browse context changes.
class MarketBrowseSessionTransition extends StatelessWidget {
  const MarketBrowseSessionTransition({
    super.key,
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  static const _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedOpacity(
          duration: _duration,
          curve: Curves.easeOutCubic,
          opacity: active ? 0.34 : 1,
          child: IgnorePointer(
            ignoring: active,
            child: child,
          ),
        ),
        IgnorePointer(
          child: AnimatedOpacity(
            duration: _duration,
            curve: Curves.easeOutCubic,
            opacity: active ? 1 : 0,
            child: const _MarketBrowseTransitionIndicator(),
          ),
        ),
      ],
    );
  }
}

class _MarketBrowseTransitionIndicator extends StatelessWidget {
  const _MarketBrowseTransitionIndicator();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Updating listings',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared padding for browse loading placeholders (search + market tab).
EdgeInsets get _marketBrowseSkeletonPadding =>
    const EdgeInsets.fromLTRB(20, 8, 20, 24);

/// Scrollable placeholders for bounded boxes (e.g. search overlay [Expanded]).
///
/// Do not place inside [SliverFillRemaining] with `hasScrollBody: false` — use
/// [MarketBrowseSliverResultsSkeleton] instead.
class MarketBrowseResultsSkeleton extends StatelessWidget {
  const MarketBrowseResultsSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: _marketBrowseSkeletonPadding,
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(
        height: FeedRhythm.marketListingFeedCardVerticalGap,
      ),
      itemBuilder: (_, _) => const _MarketBrowseSkeletonCard(),
    );
  }
}

/// Intrinsic-safe placeholders for [SliverFillRemaining] (no scroll viewport).
class MarketBrowseSliverResultsSkeleton extends StatelessWidget {
  const MarketBrowseSliverResultsSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: _marketBrowseSkeletonPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0)
                const SizedBox(height: FeedRhythm.marketListingFeedCardVerticalGap),
              const _MarketBrowseSkeletonCard(),
            ],
          ],
        ),
      ),
    );
  }
}

class _MarketBrowseSkeletonCard extends StatelessWidget {
  const _MarketBrowseSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thumb = FeedRhythm.marketListingThumbnailExtent;
    final fill = scheme.surfaceContainerHighest.withValues(alpha: 0.72);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBlock(width: thumb, height: thumb, fill: fill),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBlock(width: double.infinity, height: 14, fill: fill),
                  const SizedBox(height: 8),
                  _SkeletonBlock(width: 120, height: 12, fill: fill),
                  const SizedBox(height: 12),
                  _SkeletonBlock(width: 72, height: 16, fill: fill),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    required this.fill,
  });

  final double width;
  final double height;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
