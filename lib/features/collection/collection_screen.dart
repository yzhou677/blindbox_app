import 'dart:async';

import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/navigation/shell_tab_reselect_bus.dart';
import 'package:blindbox_app/features/collection/debug/collection_shelf_pipeline_trace.dart';
import 'package:blindbox_app/features/collection/domain/shelf_emotional_profile.dart';
import 'package:blindbox_app/features/collection/domain/shelf_relationship_insight.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_identity.dart';
import 'package:blindbox_app/features/collection/presentation/collection_modal_overlays.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_brand_facets.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_ip_facets.dart';
import 'package:blindbox_app/features/collection/widgets/custom_series_form_sheet.dart';
import 'package:blindbox_app/features/collection/widgets/add_to_collection_sheet.dart';
import 'package:blindbox_app/features/collection/widgets/collection_brand_filter_row.dart';
import 'package:blindbox_app/features/collection/widgets/collection_ip_filter_row.dart';
import 'package:blindbox_app/features/collectible_relationship/application/collectible_relationship_providers.dart';
import 'package:blindbox_app/features/collection/application/shelf_emotional_providers.dart';
import 'package:blindbox_app/features/collection/insights/application/collector_type_providers.dart';
import 'package:blindbox_app/features/collection/presentation/collection_summary_editorial.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_editorial_voice.dart';
import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/core/search/search_placeholders.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_service.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/collection_empty_state.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:blindbox_app/features/collection/widgets/collection_warm_start_banner.dart';
import 'package:blindbox_app/features/collection/widgets/series_figures_sheet.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_series_feed.dart';
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
    setState(() {});
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
    ShellTabReselectBus.instance.reselectedBranch.removeListener(_onTabReselected);
    _searchController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final trace = CollectionShelfPipelineTrace.start();
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final snap = ref.watch(collectionNotifierProvider);

    late final ShelfEmotionalProfile profile;
    late final List<ShelfRelationshipInsight> insights;
    late final String interpretationLine;
    late final String? memoryWhisper;
    late final String? relationshipWhisper;
    late final CollectorTypeIdentity? collectorIdentity;
    late final String? sectionSubtitle;
    trace.sectionVoid('Insights', () {
      profile = ref.watch(shelfEmotionalProfileProvider);
      insights = ref.watch(shelfRelationshipInsightsProvider);
      interpretationLine = ref.watch(shelfInterpretationLineProvider);
      memoryWhisper = ref.watch(shelfMemoryWhisperProvider);
      relationshipWhisper = ref.watch(shelfRelationshipWhisperProvider);
      collectorIdentity = ref.watch(collectorTypeIdentityProvider);
      sectionSubtitle = ShelfEditorialVoice.sectionSubtitle(
        profile,
        insights,
      );
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
      visible = shelfSeriesVisibleForIpFilter(
        brandFiltered,
        activeIpFilterId,
      );
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
    final catalog = ref.watch(catalogBundleProvider).valueOrNull;
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
    final collapsedIpKeys = shelfUiPrefs.collapsedIpSectionKeys;
    late final List<ShelfFeedItem> inProgressFeed;
    late final List<ShelfFeedItem> completedFeed;
    trace.sectionVoid('Feed', () {
      inProgressFeed = buildShelfFeedItems(
        context: context,
        series: inProgress,
        figureStates: snap.figureStates,
        profile: profile,
        collapseBucketKey: shelfCollapseBucketInProgress,
        collapsedSectionKeys: collapsedIpKeys,
        progress: progressLookup,
      );
      completedFeed = buildShelfFeedItems(
        context: context,
        series: completed,
        figureStates: snap.figureStates,
        profile: profile,
        collapseBucketKey: shelfCollapseBucketCompleted,
        collapsedSectionKeys: collapsedIpKeys,
        progress: progressLookup,
      );
    });
    final summaryStats = trace.section(
      'Summary',
      () => CollectionAggregateStats.fromSnapshot(snap),
    );
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
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: FeedRhythm.belowMainTabAppBar),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: FeedRhythm.headerToSearchField),
              child: AppSearchField(
                controller: _searchController,
                hintText: SearchPlaceholders.localCatalog,
                onChanged: _onSearchChanged,
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () {
                          _searchDebounceTimer?.cancel();
                          _searchController.clear();
                          if (_debouncedSearchQuery.isNotEmpty) {
                            setState(() => _debouncedSearchQuery = '');
                          } else {
                            setState(() {});
                          }
                        },
                      )
                    : null,
              ),
            ),
          ),
          if (snap.showWarmStartBanner)
            const SliverToBoxAdapter(child: CollectionWarmStartBanner()),
          if (!snap.showWarmStartBanner)
            const SliverToBoxAdapter(
              child: SizedBox(height: FeedRhythm.collectionSearchToSummaryGap),
            ),
          SliverToBoxAdapter(
            child: CollectionSummarySection(
              stats: summaryStats,
              shelfMoodLine: interpretationLine.isNotEmpty
                  ? interpretationLine
                  : CollectionSummaryEditorial.shelfMoodLine(snap),
              memoryWhisper: memoryWhisper ?? relationshipWhisper,
              collectorTypeName: collectorIdentity?.archetype.displayName,
              onInsightsTap: () => context.push('/collection/insights'),
            ),
          ),
          SliverToBoxAdapter(
            child: CollectibleSectionHeader(
              title: 'My collection',
              subtitle: sectionSubtitle,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              trailing: _CollectionAddSeriesButton(
                onPressed: () => _openAddToCollection(context),
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
                    onBrandSelected: (id) => setState(() => _brandFilterId = id),
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
            if (showInProgressSection && shelfUiPrefs.inProgressSectionExpanded)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  showCompletedSection ? 8 : FeedRhythm.tabScrollTailPadding,
                ),
                sliver: SliverList.builder(
                  itemCount: inProgressFeed.length,
                  itemBuilder: (context, i) => buildShelfFeedItemWidget(
                    context: context,
                    inProgressFeed[i],
                    collapsedSectionKeys: collapsedIpKeys,
                    onToggleIpSection: (key) => ref
                        .read(collectionShelfUiPrefsProvider.notifier)
                        .toggleIpSection(key),
                    onOpen: (s) => _openFiguresSheet(context, s.id),
                    onRemove: (s) =>
                        _confirmRemoveSeries(context, s.id, s.name),
                  ),
                ),
              ),
            if (showCompletedSection)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  showInProgressSection ? 0 : FeedRhythm.collectionFilterToFirstCard,
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
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  FeedRhythm.tabScrollTailPadding,
                ),
                sliver: SliverList.builder(
                  itemCount: completedFeed.length,
                  itemBuilder: (context, i) => buildShelfFeedItemWidget(
                    context: context,
                    completedFeed[i],
                    collapsedSectionKeys: collapsedIpKeys,
                    onToggleIpSection: (key) => ref
                        .read(collectionShelfUiPrefsProvider.notifier)
                        .toggleIpSection(key),
                    onOpen: (s) => _openFiguresSheet(context, s.id),
                    onRemove: (s) =>
                        _confirmRemoveSeries(context, s.id, s.name),
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
            fontWeight: FontWeight.w500,
            letterSpacing: 0.28,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.58),
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
                      fontWeight:
                          sort == selected ? FontWeight.w600 : FontWeight.w500,
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
              color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
              fontWeight: FontWeight.w500,
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
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withValues(alpha: 0.88),
                ),
              ),
            ),
            Icon(
              expanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 22,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
            ),
          ],
        ),
      ),
    );
  }
}
