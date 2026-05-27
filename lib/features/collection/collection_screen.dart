import 'dart:async';

import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/navigation/shell_tab_reselect_bus.dart';
import 'package:blindbox_app/features/collection/presentation/collection_modal_overlays.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_series_filter.dart';
import 'package:blindbox_app/features/collection/widgets/add_custom_series_sheet.dart';
import 'package:blindbox_app/features/collection/widgets/add_to_collection_sheet.dart';
import 'package:blindbox_app/features/collection/widgets/collection_brand_filter_row.dart';
import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_providers.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_providers.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_editorial_voice.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_series_feed.dart';
import 'package:blindbox_app/features/collection/widgets/collection_empty_state.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:blindbox_app/features/collection/widgets/collection_warm_start_banner.dart';
import 'package:blindbox_app/features/collection/widgets/series_figures_sheet.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  /// Presentation-only brand facet; aligns with [MarketTaxonomyIds.anyBrand] / brand ids.
  String _brandFilterId = MarketTaxonomyIds.anyBrand;

  final ScrollController _scrollController = ScrollController();
  VoidCallback? _routerListener;

  @override
  void initState() {
    super.initState();
    CollectionModalOverlayRegistry.instance.register(_dismissBranchOverlays);
    ShellTabReselectBus.instance.reselectedBranch.addListener(_onTabReselected);
  }

  void _onTabReselected() {
    if (ShellTabReselectBus.instance.reselectedBranch.value !=
        kCollectionShellBranchIndex) {
      return;
    }
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routerListener != null) return;
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    _routerListener = () {
      final path = router.state.uri.path;
      // Route the dismiss request through the registry so the reentrancy
      // guard catches the case where MainShellScaffold has already requested
      // a dismiss for the same tab switch (the router listener fires
      // immediately after shell.goBranch() and would otherwise call popUntil
      // a second time while the first pop animation is still in flight).
      if (!path.startsWith('/collection') && mounted) {
        unawaited(CollectionModalOverlayRegistry.instance.dismissAll());
      }
    };
    router.routerDelegate.addListener(_routerListener!);
  }

  Future<void> _dismissBranchOverlays() async {
    if (!mounted) return;
    await dismissCollectionModalOverlays(context);
  }

  @override
  void dispose() {
    ShellTabReselectBus.instance.reselectedBranch.removeListener(_onTabReselected);
    _scrollController.dispose();
    CollectionModalOverlayRegistry.instance.unregister();
    if (_routerListener != null) {
      try {
        GoRouter.maybeOf(context)?.routerDelegate.removeListener(_routerListener!);
      } catch (_) {
        // Context may already be unmounted.
      }
    }
    super.dispose();
  }

  void _openFiguresSheet(BuildContext context, String seriesId) {
    showCollectibleBottomSheet<void>(
      context: context,
      heightFraction: FeedRhythm.sheetFiguresOpenScreenFraction,
      builder: (_, scroll) => SeriesFiguresSheet(seriesId: seriesId),
    );
  }

  Future<void> _confirmRemoveSeries(
    BuildContext context,
    String id,
    String name,
  ) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Remove series?'),
          content: Text('“$name” will leave your shelf.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    if (go == true && context.mounted) {
      ref.read(collectionNotifierProvider.notifier).removeSeries(id);
    }
  }

  void _openAddCustom(BuildContext context) {
    showCollectionModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_, scroll) => AddCustomSeriesSheet(
          onSubmit:
              ({
                required String seriesName,
                String? brand,
                String? ipDisplayName,
                required List<CustomFigureDraft> figures,
                String? customCoverImageUri,
                String? notes,
              }) {
                ref
                    .read(collectionNotifierProvider.notifier)
                    .addCustomSeries(
                      seriesName: seriesName,
                      brand: brand,
                      ipDisplayName: ipDisplayName,
                      figures: figures,
                      customCoverImageUri: customCoverImageUri,
                      notes: notes,
                    );
              },
      ),
    );
  }

  void _openAddToCollection(BuildContext context) {
    showCollectionModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx, scroll) => AddToCollectionSheet(
          onCreateCustom: () {
            // Guard against double-tap: only pop if the sheet route is still
            // current.  Without this, a rapid second tap can call pop() on a
            // route already mid-pop and complete its future twice.
            final navigator = Navigator.of(ctx);
            if (navigator.canPop()) navigator.pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                _openAddCustom(context);
              }
            });
          },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final snap = ref.watch(collectionNotifierProvider);
    final profile = ref.watch(shelfEmotionalProfileProvider);
    final insights = ref.watch(shelfRelationshipInsightsProvider);
    final interpretationLine = ref.watch(shelfInterpretationLineProvider);
    final memoryWhisper = ref.watch(shelfMemoryWhisperProvider);
    final relationshipWhisper = ref.watch(shelfRelationshipWhisperProvider);
    final collectorIdentity = ref.watch(collectorTypeIdentityProvider);
    final sectionSubtitle = ShelfEditorialVoice.sectionSubtitle(
      profile,
      insights,
    );

    // Compute filtered series and lazy feed items (data-only, no widgets).
    // Off-screen cards are built on demand by the SliverList.builder below.
    final visible = shelfSeriesVisibleForBrandFilter(
      snap.shelfSeries,
      _brandFilterId,
    );
    final feedItems = buildShelfFeedItems(
      context: context,
      series: visible,
      figureStates: snap.figureStates,
      profile: profile,
    );

    if (snap.trackedSeriesCount == 0) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: false,
              floating: false,
              elevation: 0,
              scrolledUnderElevation: 0,
              toolbarHeight: FeedRhythm.mainTabAppBarToolbarHeight,
              backgroundColor: scheme.surface,
              centerTitle: false,
              titleSpacing: 20,
              title: Text('My collection', style: textTheme.titleLarge),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: FeedRhythm.belowMainTabAppBar),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: CollectionEmptyState(
                onAddSeries: () => _openAddToCollection(context),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: false,
            floating: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: FeedRhythm.mainTabAppBarToolbarHeight,
            backgroundColor: scheme.surface,
            centerTitle: false,
            titleSpacing: 20,
            title: Text('My collection', style: textTheme.titleLarge),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: FeedRhythm.belowMainTabAppBar),
          ),
          if (snap.isWarmStart)
            const SliverToBoxAdapter(child: CollectionWarmStartBanner()),
          SliverToBoxAdapter(
            child: CollectionSummarySection(
              stats: CollectionAggregateStats.fromSnapshot(snap),
              shelfMoodLine: interpretationLine.isNotEmpty
                  ? interpretationLine
                  : ShelfEditorialVoice.shelfMoodLine(snap),
              memoryWhisper: memoryWhisper ?? relationshipWhisper,
              collectorTypeName: collectorIdentity?.archetype.displayName,
              onInsightsTap: () => context.push('/collection/insights'),
            ),
          ),
          SliverToBoxAdapter(
            child: CollectibleSectionHeader(
              title: 'My collection',
              subtitle: sectionSubtitle,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              trailing: TextButton.icon(
                key: const Key('collection_header_add_series'),
                onPressed: () => _openAddToCollection(context),
                icon: Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: scheme.primary.withValues(alpha: 0.72),
                ),
                label: Text(
                  'Add series',
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.02,
                    height: 1.1,
                    color: scheme.primary.withValues(alpha: 0.78),
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Color.lerp(
                    scheme.surface,
                    scheme.primaryContainer,
                    Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.32,
                  ),
                  foregroundColor: scheme.primary.withValues(alpha: 0.78),
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  padding: const EdgeInsetsDirectional.only(
                    start: 8,
                    end: 10,
                    top: 8,
                    bottom: 8,
                  ),
                  minimumSize: const Size(48, 40),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: CollectionBrandFilterRow(
                selectedBrandId: _brandFilterId,
                onBrandSelected: (id) => setState(() => _brandFilterId = id),
              ),
            ),
          ),
          if (visible.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Nothing on your shelf for this brand yet.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                    height: 1.4,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                20,
                FeedRhythm.collectionFilterToFirstCard,
                20,
                FeedRhythm.tabScrollTailPadding,
              ),
              sliver: SliverList.builder(
                itemCount: feedItems.length,
                itemBuilder: (context, i) => buildShelfFeedItemWidget(
                  feedItems[i],
                  onOpen: (s) => _openFiguresSheet(context, s.id),
                  onRemove: (s) =>
                      _confirmRemoveSeries(context, s.id, s.name),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
