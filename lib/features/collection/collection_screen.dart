import 'dart:async';

import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/navigation/shell_tab_reselect_bus.dart';
import 'package:blindbox_app/features/collection/debug/collection_shelf_pipeline_trace.dart';
import 'package:blindbox_app/features/collection/domain/shelf_emotional_profile.dart';
import 'package:blindbox_app/features/collection/domain/shelf_relationship_insight.dart';
import 'package:blindbox_app/features/collection/presentation/collection_modal_overlays.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_management.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/share_payload_builders/shelf_share_payload_builder.dart';
import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_ip_facets.dart';
import 'package:blindbox_app/features/collection/widgets/custom_series_form_sheet.dart';
import 'package:blindbox_app/features/collection/widgets/add_to_collection_sheet.dart';
import 'package:blindbox_app/features/collection/widgets/collection_brand_filter_row.dart';
import 'package:blindbox_app/features/collection/widgets/collection_ip_filter_row.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_providers.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_editorial_voice.dart';
import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/core/search/search_placeholders.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_service.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_view_model.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collection_insights_body.dart';
import 'package:blindbox_app/features/collection/insights/presentation/collector_type_copy.dart';
import 'package:blindbox_app/features/collection/widgets/collection_empty_state.dart';
import 'package:blindbox_app/features/collection/widgets/collection_insights_dashboard_host.dart';
import 'package:blindbox_app/features/collection/widgets/collection_page_segment_control.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_series_rail.dart';
import 'package:blindbox_app/features/collection/widgets/collection_warm_start_banner.dart';
import 'package:blindbox_app/features/collection/widgets/series_figures_sheet.dart';
import 'package:blindbox_app/features/sharing/presentation/share_card_preview.dart';
import 'package:blindbox_app/features/sharing/presentation/widgets/shelfy_collector_cards.dart';
import 'package:blindbox_app/shared/widgets/app_search_field.dart';
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
  static const _searchDebounce = Duration(milliseconds: 125);

  /// Presentation-only Collection shelf brand facet.
  String _brandFilterId = collectionAnyBrandFilterId;

  /// Presentation-only Collection shelf IP facet (scoped to brand-filtered series).
  String _ipFilterId = collectionAnyIpFilterId;

  /// Presentation-only Shelf / Insights section switch.
  CollectionPageSegment _pageSegment = CollectionPageSegment.shelf;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  VoidCallback? _routerListener;
  Timer? _searchDebounceTimer;

  /// Debounced query for the browse pipeline — text field updates immediately.
  String _debouncedSearchQuery = '';

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

  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    if (normalizeCatalogSearchQuery(value).isEmpty) {
      if (_debouncedSearchQuery.isNotEmpty) {
        setState(() => _debouncedSearchQuery = '');
      }
      return;
    }
    _searchDebounceTimer = Timer(_searchDebounce, () {
      if (!mounted) return;
      final next = _searchController.text;
      if (next == _debouncedSearchQuery) return;
      setState(() => _debouncedSearchQuery = next);
    });
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
    _searchDebounceTimer?.cancel();
    ShellTabReselectBus.instance.reselectedBranch.removeListener(
      _onTabReselected,
    );
    _searchController.dispose();
    _scrollController.dispose();
    CollectionModalOverlayRegistry.instance.unregister();
    if (_routerListener != null) {
      try {
        GoRouter.maybeOf(
          context,
        )?.routerDelegate.removeListener(_routerListener!);
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

  Future<void> _manageSeries(BuildContext context, ShelfSeries series) {
    return showCollectionSeriesManagementActions(
      context: context,
      ref: ref,
      series: series,
    );
  }

  void _openAddCustom(BuildContext context) {
    showCollectionModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_, scroll) => CustomSeriesFormSheet.create(
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

  void _shareShelf(BuildContext context) {
    final snap = ref.read(collectionNotifierProvider);
    final identity = ref.read(collectorTypeIdentityProvider);
    final payload = buildShelfSharePayload(
      snapshot: snap,
      collectorTypeIdentity: identity,
    );
    showShareCardPreview(
      context: context,
      card: ShelfShareCard(payload: payload),
      basename: 'shelfy-shelf-card',
      loadingLabel: 'Creating your Shelf Card...',
      previewTitle: 'Shelf Card',
    );
  }

  @override
  Widget build(BuildContext context) {
    final trace = CollectionShelfPipelineTrace.start();
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final snap = ref.watch(collectionNotifierProvider);

    late final ShelfEmotionalProfile profile;
    late final List<ShelfRelationshipInsight> insights;
    late final String? sectionSubtitle;
    trace.sectionVoid('Insights', () {
      profile = ref.watch(shelfEmotionalProfileProvider);
      insights = ref.watch(shelfRelationshipInsightsProvider);
      sectionSubtitle = ShelfEditorialVoice.sectionSubtitle(profile, insights);
    });

    late final List<CollectionBrandFilterOption> brandFilterOptions;
    late final String activeBrandFilterId;
    late final List<ShelfSeries> brandFiltered;
    late final List<CollectionIpFilterOption> ipFilterOptions;
    late final String activeIpFilterId;
    late final List<ShelfSeries> visible;
    trace.sectionVoid('Filter', () {
      brandFilterOptions = buildCollectionShelfBrandFilterOptions(
        snap.shelfSeries,
      );
      activeBrandFilterId = resolveCollectionBrandFilterSelection(
        selectedBrandFilterId: _brandFilterId,
        options: brandFilterOptions,
      );
      brandFiltered = shelfSeriesVisibleForBrandFilter(
        snap.shelfSeries,
        activeBrandFilterId,
      );
      ipFilterOptions = buildCollectionShelfIpFilterOptions(brandFiltered);
      activeIpFilterId = resolveCollectionIpFilterSelection(
        selectedIpFilterId: _ipFilterId,
        options: ipFilterOptions,
      );
      visible = shelfSeriesVisibleForIpFilter(brandFiltered, activeIpFilterId);
    });
    if (activeBrandFilterId != _brandFilterId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _brandFilterId = activeBrandFilterId);
      });
    }
    if (activeIpFilterId != _ipFilterId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _ipFilterId = activeIpFilterId);
      });
    }

    // Browse pipeline: brand → IP → search → partition → sort each bucket.
    final shelfUiPrefs = ref.watch(collectionShelfUiPrefsProvider);
    final catalog = resolveCatalogBundleForSearch(
      providerBundle: ref.watch(catalogBundleProvider).valueOrNull,
    );
    final catalogSearch = ref.watch(catalogSearchServiceProvider);
    final progressLookup = ShelfBrowseProgressLookup(snap.figureStates);
    final searched = trace.section(
      'Search',
      () => filterShelfSeriesBySearch(
        visible,
        _debouncedSearchQuery,
        catalog: catalog,
        catalogSearch: catalogSearch,
      ),
    );
    final (inProgressRaw, completedRaw) = trace.section(
      'Partition',
      () => partitionShelfSeries(
        searched,
        snap.figureStates,
        progress: progressLookup,
      ),
    );
    late final List<ShelfSeries> inProgress;
    late final List<ShelfSeries> completed;
    trace.sectionVoid('Sort', () {
      inProgress = sortShelfSeriesForDisplay(
        inProgressRaw,
        shelfUiPrefs.sort,
        snap.figureStates,
        progress: progressLookup,
      );
      completed = sortShelfSeriesForDisplay(
        completedRaw,
        shelfUiPrefs.sort,
        snap.figureStates,
        progress: progressLookup,
      );
    });
    final brandFilterExhausted = brandFiltered.isEmpty;
    final ipFilterExhausted = !brandFilterExhausted && visible.isEmpty;
    final searchExhausted =
        !brandFilterExhausted && !ipFilterExhausted && searched.isEmpty;
    final showInProgressSection = inProgress.isNotEmpty;
    final showCompletedSection = completed.isNotEmpty;

    if (snap.trackedSeriesCount == 0) {
      trace.finish(
        shelfSeries: 0,
        visibleSeries: 0,
        catalogSeries: catalog?.series.length,
        catalogFigures: catalog?.figures.length,
        note: 'empty shelf',
      );
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
              actions: _insightsAppBarActions(ref),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: FeedRhythm.belowMainTabAppBar),
            ),
            SliverToBoxAdapter(
              child: CollectionPageSegmentControl(
                selected: _pageSegment,
                onChanged: _onPageSegmentChanged,
              ),
            ),
            if (_pageSegment == CollectionPageSegment.insights)
              const SliverToBoxAdapter(child: CollectionInsightsBody())
            else
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

    final scaffold = Scaffold(
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
            actions: _insightsAppBarActions(ref),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: FeedRhythm.belowMainTabAppBar),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: FeedRhythm.headerToSearchField,
              ),
              child: AppSearchField(
                controller: _searchController,
                hintText: SearchPlaceholders.collection,
                onChanged: _onSearchChanged,
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () {
                        _searchDebounceTimer?.cancel();
                        _searchController.clear();
                        if (_debouncedSearchQuery.isNotEmpty) {
                          setState(() => _debouncedSearchQuery = '');
                        }
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          if (snap.showWarmStartBanner)
            const SliverToBoxAdapter(child: CollectionWarmStartBanner()),
          if (!snap.showWarmStartBanner)
            const SliverToBoxAdapter(
              child: SizedBox(height: FeedRhythm.collectionSearchToSummaryGap),
            ),
          SliverToBoxAdapter(child: CollectionInsightsDashboardHost()),
          SliverToBoxAdapter(
            child: CollectionPageSegmentControl(
              selected: _pageSegment,
              onChanged: _onPageSegmentChanged,
            ),
          ),
          if (_pageSegment == CollectionPageSegment.insights)
            const SliverToBoxAdapter(child: CollectionInsightsBody())
          else ...[
            SliverToBoxAdapter(
              child: CollectibleSectionHeader(
                title: 'My collection',
                subtitle: sectionSubtitle,
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
                trailing: _CollectionHeaderActions(
                  onShare: () => _shareShelf(context),
                  onAddSeries: () => _openAddToCollection(context),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CollectionBrowseFilterLabel(text: 'Brand'),
                    const SizedBox(
                      height: FeedRhythm.collectionFilterSectionLabelToRail,
                    ),
                    CollectionBrandFilterRow(
                      options: brandFilterOptions,
                      selectedBrandId: activeBrandFilterId,
                      onBrandSelected: (id) =>
                          setState(() => _brandFilterId = id),
                    ),
                    const SizedBox(
                      height: FeedRhythm.collectionBrandToIpFilterSectionGap,
                    ),
                    _CollectionBrowseFilterLabel(text: 'IP'),
                    const SizedBox(
                      height: FeedRhythm.collectionFilterSectionLabelToRail,
                    ),
                    CollectionIpFilterRow(
                      options: ipFilterOptions,
                      selectedIpId: activeIpFilterId,
                      onIpSelected: (id) => setState(() => _ipFilterId = id),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _CollectionShelfSortMenu(
                          selected: shelfUiPrefs.sort,
                          onSelected: (sort) => ref
                              .read(collectionShelfUiPrefsProvider.notifier)
                              .setSort(sort),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (brandFilterExhausted || ipFilterExhausted)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    brandFilterExhausted
                        ? 'Nothing on your shelf for this brand yet.'
                        : 'Nothing on your shelf for this IP yet.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                      height: 1.4,
                    ),
                  ),
                ),
              )
            else if (searchExhausted)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'No series match your search.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                      height: 1.4,
                    ),
                  ),
                ),
              )
            else ...[
              if (showInProgressSection)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    FeedRhythm.collectionFilterToFirstCard,
                    20,
                    shelfUiPrefs.inProgressSectionExpanded ? 8 : 0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _ShelfBucketSectionHeader(
                      title: 'In progress',
                      count: inProgress.length,
                      expanded: shelfUiPrefs.inProgressSectionExpanded,
                      onToggle: () => ref
                          .read(collectionShelfUiPrefsProvider.notifier)
                          .toggleInProgressSection(),
                    ),
                  ),
                ),
              if (showInProgressSection &&
                  shelfUiPrefs.inProgressSectionExpanded)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: showCompletedSection
                          ? 8
                          : FeedRhythm.tabScrollTailPadding,
                    ),
                    child: CollectionShelfSeriesRail(
                      series: inProgress,
                      figureStates: snap.figureStates,
                      progress: progressLookup,
                      onOpen: (s) => _openFiguresSheet(context, s.id),
                      onManage: (s) => _manageSeries(context, s),
                    ),
                  ),
                ),
              if (showCompletedSection)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    showInProgressSection
                        ? 0
                        : FeedRhythm.collectionFilterToFirstCard,
                    20,
                    shelfUiPrefs.completedSectionExpanded
                        ? 8
                        : FeedRhythm.tabScrollTailPadding,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _ShelfBucketSectionHeader(
                      title: 'Completed',
                      count: completed.length,
                      expanded: shelfUiPrefs.completedSectionExpanded,
                      onToggle: () => ref
                          .read(collectionShelfUiPrefsProvider.notifier)
                          .toggleCompletedSection(),
                    ),
                  ),
                ),
              if (showCompletedSection && shelfUiPrefs.completedSectionExpanded)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: FeedRhythm.tabScrollTailPadding,
                    ),
                    child: CollectionShelfSeriesRail(
                      series: completed,
                      figureStates: snap.figureStates,
                      progress: progressLookup,
                      onOpen: (s) => _openFiguresSheet(context, s.id),
                      onManage: (s) => _manageSeries(context, s),
                    ),
                  ),
                ),
              if (inProgress.isNotEmpty &&
                  showCompletedSection &&
                  !shelfUiPrefs.inProgressSectionExpanded &&
                  !shelfUiPrefs.completedSectionExpanded)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Expand a section above to browse your shelf.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
    trace.finish(
      shelfSeries: snap.shelfSeries.length,
      visibleSeries: searched.length,
      catalogSeries: catalog?.series.length,
      catalogFigures: catalog?.figures.length,
    );
    return scaffold;
  }

  void _onPageSegmentChanged(CollectionPageSegment next) {
    if (next == _pageSegment) return;
    setState(() => _pageSegment = next);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  List<Widget> _insightsAppBarActions(WidgetRef ref) {
    if (_pageSegment != CollectionPageSegment.insights) {
      return const [];
    }
    final needsReveal = ref.watch(collectorTypeNeedsRevealProvider);
    final stage = ref.watch(collectorTypeViewModelProvider);
    final showRevealAgainMenu =
        stage is CollectorTypeRevealRevealed && !needsReveal;
    if (!showRevealAgainMenu) return const [];
    return [
      PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'reveal') {
            ref.read(collectorTypeViewModelProvider.notifier).requestReveal();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'reveal',
            child: Text(CollectorTypeCopy.revealAgain),
          ),
        ],
      ),
    ];
  }
}

class _CollectionBrowseFilterLabel extends StatelessWidget {
  const _CollectionBrowseFilterLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.32,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
          ),
        ),
      ),
    );
  }
}

class _CollectionAddSeriesButton extends StatelessWidget {
  const _CollectionAddSeriesButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return TextButton.icon(
      key: const Key('collection_header_add_series'),
      onPressed: onPressed,
      icon: Icon(
        Icons.add_rounded,
        size: 16,
        color: scheme.primary.withValues(alpha: 0.72),
      ),
      label: Text(
        'Add series',
        style: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.02,
          height: 1.1,
          color: scheme.primary.withValues(alpha: 0.88),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _CollectionHeaderActions extends StatelessWidget {
  const _CollectionHeaderActions({
    required this.onShare,
    required this.onAddSeries,
  });

  final VoidCallback onShare;
  final VoidCallback onAddSeries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: 'Share shelf card',
          onPressed: onShare,
          style: IconButton.styleFrom(
            backgroundColor: Color.lerp(
              scheme.surface,
              scheme.primaryContainer,
              Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.28,
            ),
            foregroundColor: scheme.primary.withValues(alpha: 0.78),
            minimumSize: const Size(40, 40),
            tapTargetSize: MaterialTapTargetSize.padded,
            visualDensity: VisualDensity.compact,
          ),
          icon: const Icon(Icons.ios_share_rounded, size: 18),
        ),
        const SizedBox(width: 8),
        _CollectionAddSeriesButton(onPressed: onAddSeries),
      ],
    );
  }
}

class _CollectionShelfSortMenu extends StatelessWidget {
  const _CollectionShelfSortMenu({
    required this.selected,
    required this.onSelected,
  });

  final CollectionShelfSort selected;
  final ValueChanged<CollectionShelfSort> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopupMenuButton<CollectionShelfSort>(
      key: const Key('collection_shelf_sort_menu'),
      initialValue: selected,
      tooltip: 'Sort shelf',
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem<CollectionShelfSort>(
          enabled: false,
          height: 40,
          child: Text(
            'Sort by',
            style: textTheme.titleSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ),
        for (final sort in CollectionShelfSort.values)
          PopupMenuItem<CollectionShelfSort>(
            value: sort,
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: sort == selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: scheme.primary,
                        )
                      : null,
                ),
                Expanded(
                  child: Text(
                    sort.menuLabel,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: sort == selected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sort_rounded,
            size: 18,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
          ),
          const SizedBox(width: 6),
          Text(
            selected.menuLabel,
            style: textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          Icon(
            Icons.expand_more_rounded,
            size: 18,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
          ),
        ],
      ),
    );
  }
}

class _ShelfBucketSectionHeader extends StatelessWidget {
  const _ShelfBucketSectionHeader({
    required this.title,
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$title ($count)',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface.withValues(alpha: 0.92),
                ),
              ),
            ),
            Icon(
              expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 22,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
            ),
          ],
        ),
      ),
    );
  }
}
