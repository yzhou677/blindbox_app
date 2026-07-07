import 'package:blindbox_app/core/search/search_placeholders.dart';
import 'package:blindbox_app/features/catalog/application/catalog_availability.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_availability_copy.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_search_host_actions.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_series_search_rows.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_history_provider.dart';
import 'package:blindbox_app/features/catalog/search/catalog_search_history_section.dart';
import 'package:blindbox_app/features/catalog/widgets/catalog_availability_card.dart';
import 'package:blindbox_app/features/catalog/widgets/catalog_series_search_row_card.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/presentation/collection_series_shelf_cta_presentation.dart';
import 'package:blindbox_app/shared/widgets/app_search_field.dart';
import 'package:blindbox_app/shared/widgets/feed_search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared catalog search experience — field, history, results, availability.
///
/// Hosts supply [CatalogSearchHostActions] for preview / add; this widget has no
/// routing knowledge.
class CatalogSearchExperience extends ConsumerStatefulWidget {
  const CatalogSearchExperience({
    super.key,
    required this.actions,
    this.presentation = CatalogSearchPresentation.discoverScreen,
    this.idleBody = CatalogSearchIdleBody.recentSearches,
    this.initialQuery,
    this.hintText,
    this.fieldPadding,
    this.autofocus,
    this.onActiveQueryChanged,
  });

  final CatalogSearchHostActions actions;
  final CatalogSearchPresentation presentation;
  final CatalogSearchIdleBody idleBody;
  final String? initialQuery;
  final String? hintText;
  final EdgeInsetsGeometry? fieldPadding;
  final bool? autofocus;
  final ValueChanged<bool>? onActiveQueryChanged;

  /// Test-only rebuild counter for search typing regression.
  @visibleForTesting
  static int debugBuildCount = 0;

  @override
  ConsumerState<CatalogSearchExperience> createState() =>
      _CatalogSearchExperienceState();
}

class _CatalogSearchExperienceState
    extends ConsumerState<CatalogSearchExperience> {
  final _search = TextEditingController();
  bool _queryActive = false;

  @override
  void initState() {
    super.initState();
    final initialQuery = widget.initialQuery?.trim();
    if (initialQuery != null && initialQuery.isNotEmpty) {
      _search.text = initialQuery;
      _search.selection = TextSelection.collapsed(offset: initialQuery.length);
      _queryActive = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onActiveQueryChanged?.call(true);
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _trimmedQuery => _search.text.trim();

  bool get _hasSearchText => _trimmedQuery.isNotEmpty;

  String get _hintText =>
      widget.hintText ?? SearchPlaceholders.discoverCatalog;

  bool get _autofocus =>
      widget.autofocus ??
      widget.presentation == CatalogSearchPresentation.discoverScreen;

  void _notifyQueryActiveChanged(bool active) {
    if (_queryActive == active) return;
    _queryActive = active;
    widget.onActiveQueryChanged?.call(active);
  }

  void _onSearchChanged(String _) {
    _notifyQueryActiveChanged(_hasSearchText);
    setState(() {});
  }

  void _clearSearch() {
    final hadText = _search.text.trim().isNotEmpty;
    _search.clear();
    if (hadText) {
      _notifyQueryActiveChanged(false);
      setState(() {});
    }
  }

  void _recordSearch(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    ref.read(catalogSearchHistoryProvider.notifier).add(q);
  }

  void _scheduleDeferredSearchRecord(String? query) {
    final q = query?.trim();
    if (q == null || q.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recordSearch(q);
    });
  }

  void _applyHistoryQuery(String query) {
    _search.text = query;
    _search.selection = TextSelection.collapsed(offset: query.length);
    _notifyQueryActiveChanged(_hasSearchText);
    setState(() {});
  }

  void _applySuggestedQuery(String query) {
    _applyHistoryQuery(query);
    _recordSearch(query);
  }

  Widget _buildClearSuffix(ColorScheme scheme) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _search,
      builder: (context, value, _) {
        if (value.text.trim().isEmpty) return const SizedBox.shrink();
        return IconButton(
          tooltip: 'Clear',
          icon: Icon(
            Icons.close_rounded,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          onPressed: _clearSearch,
        );
      },
    );
  }

  Widget? _buildIdleHistorySection(List<String> history) {
    if (widget.idleBody != CatalogSearchIdleBody.recentSearches) {
      return null;
    }
    return searchEmptyQuerySection(
      history: history,
      onHistoryTap: _applyHistoryQuery,
      onRemove: (q) =>
          ref.read(catalogSearchHistoryProvider.notifier).remove(q),
      onClearAll: () =>
          ref.read(catalogSearchHistoryProvider.notifier).clearAll(),
      onSuggestedTap: _applySuggestedQuery,
    );
  }

  Widget _buildSearchRowCard(
    BuildContext context,
    CatalogSeriesSearchRow row,
    CollectionSnapshot snap,
  ) {
    final shelfCta = CollectionSeriesShelfCtaPresentation.resolve(
      snapshot: snap,
      layout: widget.actions.ctaLayout,
      catalogTemplateId: row.seriesId,
      seriesName: row.seriesTitle,
      brandName: row.brand,
      taxonomyBrandId: row.taxonomyBrandId,
      taxonomyIpId: row.taxonomyIpId,
    );
    return CatalogSeriesSearchRowCard(
      key: ValueKey<String>('catalog-search:${row.seriesId}'),
      row: row,
      shelfCta: shelfCta,
      onOpenPreview: () {
        _scheduleDeferredSearchRecord(_trimmedQuery);
        widget.actions.onOpenPreview(
          context,
          seriesId: row.seriesId,
          searchQuery: _trimmedQuery,
        );
      },
      onShelfCtaPressed: () {
        _scheduleDeferredSearchRecord(_trimmedQuery);
        widget.actions.onShelfCtaPressed(
          context,
          seriesId: row.seriesId,
          searchQuery: _trimmedQuery,
        );
      },
    );
  }

  Widget _buildDiscoverResults({
    required ColorScheme scheme,
    required TextTheme textTheme,
    required CatalogAvailability availability,
    required AsyncValue<CatalogSeedBundle> bundleAsync,
    required CollectionSnapshot snap,
    required Future<void> Function() retry,
  }) {
    if (!availability.isCatalogUsable) {
      return CatalogAvailabilitySearchMessage(
        message: CatalogAvailabilityCopy.searchMessageFor(availability),
        onRetry: availability.isOfflineFirstLaunch ? retry : null,
      );
    }

    final bundle = bundleAsync.valueOrNull;
    if (bundle == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final lookup = ref.watch(catalogBundleLookupProvider);
    final matches = buildCatalogSeriesSearchRows(
      bundle: bundle,
      query: _trimmedQuery,
      lookup: lookup,
    );
    if (matches.isEmpty) {
      return Center(
        child: Text(
          'No matches for that search.',
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: matches.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) =>
          _buildSearchRowCard(ctx, matches[i], snap),
    );
  }

  List<Widget> _buildEmbeddedResultSlivers({
    required ColorScheme scheme,
    required TextTheme textTheme,
    required CatalogAvailability availability,
    required CatalogSeedBundle? bundle,
    required CollectionSnapshot snap,
    required Future<void> Function() retry,
  }) {
    if (!availability.isCatalogUsable) {
      return [
        SliverToBoxAdapter(
          child: CatalogAvailabilitySearchMessage(
            message: CatalogAvailabilityCopy.searchMessageFor(availability),
            onRetry: availability.isOfflineFirstLaunch ? retry : null,
          ),
        ),
      ];
    }
    if (bundle == null) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }

    final lookup = ref.watch(catalogBundleLookupProvider);
    final matches = buildCatalogSeriesSearchRows(
      bundle: bundle,
      query: _trimmedQuery,
      lookup: lookup,
    );

    if (matches.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No matches for that search.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            'Matches',
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.12,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
            ),
          ),
        ),
      ),
      SliverList.separated(
        itemCount: matches.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => _buildSearchRowCard(ctx, matches[i], snap),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
    ];
  }

  Widget _buildDiscoverScreen(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bundleAsync = ref.watch(catalogBundleProvider);
    final availability = ref.watch(catalogAvailabilityProvider);
    final retry = ref.read(catalogDownloadRetryProvider);
    final snap = ref.watch(collectionNotifierProvider);
    final history = ref.watch(catalogSearchHistoryProvider);

    final Widget results;
    final Widget? historySection;
    if (!availability.isCatalogUsable) {
      final message = CatalogAvailabilityCopy.searchMessageFor(availability);
      if (_hasSearchText) {
        historySection = null;
        results = CatalogAvailabilitySearchMessage(
          message: message,
          onRetry: availability.isOfflineFirstLaunch ? retry : null,
        );
      } else {
        historySection = CatalogAvailabilityCard(
          availability: availability,
          onRetry: availability.isOfflineFirstLaunch ? retry : null,
        );
        results = const SizedBox.shrink();
      }
    } else {
      historySection = _buildIdleHistorySection(history);
      if (_hasSearchText) {
        results = _buildDiscoverResults(
          scheme: scheme,
          textTheme: textTheme,
          availability: availability,
          bundleAsync: bundleAsync,
          snap: snap,
          retry: retry,
        );
      } else {
        results = const SizedBox.shrink();
      }
    }

    return FeedSearchScreen(
      title: 'Search catalog',
      hintText: _hintText,
      emptyPrompt: 'Search by series, figure, or IP.',
      controller: _search,
      onChanged: _onSearchChanged,
      onSubmitted: () => _recordSearch(_trimmedQuery),
      onClear: _clearSearch,
      historySection: historySection,
      results: results,
    );
  }

  List<Widget> _buildEmbeddedSlivers(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bundleAsync = ref.watch(catalogBundleProvider);
    final availability = ref.watch(catalogAvailabilityProvider);
    final retry = ref.read(catalogDownloadRetryProvider);
    final snap = ref.watch(collectionNotifierProvider);
    final catalogBundle = bundleAsync.valueOrNull;

    return [
      SliverToBoxAdapter(
        child: AppSearchField(
          controller: _search,
          autofocus: _autofocus,
          padding: widget.fieldPadding ?? EdgeInsets.zero,
          hintText: _hintText,
          onChanged: _onSearchChanged,
          onSubmitted: () => _recordSearch(_trimmedQuery),
          suffixIcon: _buildClearSuffix(scheme),
        ),
      ),
      if (_hasSearchText)
        ..._buildEmbeddedResultSlivers(
          scheme: scheme,
          textTheme: textTheme,
          availability: availability,
          bundle: catalogBundle,
          snap: snap,
          retry: retry,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    assert(() {
      CatalogSearchExperience.debugBuildCount++;
      return true;
    }());

    if (widget.presentation == CatalogSearchPresentation.embeddedSlivers) {
      return SliverMainAxisGroup(slivers: _buildEmbeddedSlivers(context));
    }
    return _buildDiscoverScreen(context);
  }
}
