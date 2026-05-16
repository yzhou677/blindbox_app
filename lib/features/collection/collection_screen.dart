import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_series_filter.dart';
import 'package:blindbox_app/features/collection/widgets/add_custom_series_sheet.dart';
import 'package:blindbox_app/features/collection/widgets/add_to_collection_sheet.dart';
import 'package:blindbox_app/features/collection/widgets/collection_brand_filter_row.dart';
import 'package:blindbox_app/features/collection/widgets/collection_progress_voice.dart';
import 'package:blindbox_app/features/collection/widgets/collection_empty_state.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:blindbox_app/features/collection/widgets/collection_warm_start_banner.dart';
import 'package:blindbox_app/features/collection/widgets/series_figures_sheet.dart';
import 'package:blindbox_app/features/collection/widgets/series_shelf_cards.dart';
import 'package:blindbox_app/features/market/catalog/market_taxonomy.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  /// Presentation-only brand facet; aligns with [MarketTaxonomyIds.anyBrand] / brand ids.
  String _brandFilterId = MarketTaxonomyIds.anyBrand;

  void _openFiguresSheet(BuildContext context, String seriesId) {
    final h = MediaQuery.sizeOf(context).height * 0.74;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SizedBox(
          height: h,
          child: SeriesFiguresSheet(seriesId: seriesId),
        ),
      ),
    );
  }

  Future<void> _confirmRemoveSeries(BuildContext context, String id, String name) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Remove series?'),
          content: Text('“$name” will leave your shelf.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
          ],
        );
      },
    );
    if (go == true && context.mounted) {
      ref.read(collectionNotifierProvider.notifier).removeSeries(id);
    }
  }

  void _openAddCustom(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: AddCustomSeriesSheet(
          onSubmit: ({
            required String seriesName,
            String? brand,
            String? ipDisplayName,
            required List<String> figureNames,
            required List<String?> figureLocalImageUris,
            String? customCoverImageUri,
            String? notes,
          }) {
            ref.read(collectionNotifierProvider.notifier).addCustomSeries(
                  seriesName: seriesName,
                  brand: brand,
                  ipDisplayName: ipDisplayName,
                  figureNames: figureNames,
                  figureLocalImageUris: figureLocalImageUris,
                  customCoverImageUri: customCoverImageUri,
                  notes: notes,
                );
          },
        ),
      ),
    );
  }

  void _openAddToCollection(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: AddToCollectionSheet(
          onCreateCustom: () {
            Navigator.of(ctx).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                _openAddCustom(context);
              }
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final snap = ref.watch(collectionNotifierProvider);

    if (snap.trackedSeriesCount == 0) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: CustomScrollView(
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
              shelfMoodLine: CollectionProgressVoice.shelfMoodLine(snap),
            ),
          ),
          SliverToBoxAdapter(
            child: CollectibleSectionHeader(
              title: 'My collection',
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
                    0.32,
                  )!.withValues(alpha: 0.92),
                  foregroundColor: scheme.primary.withValues(alpha: 0.78),
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  padding: const EdgeInsetsDirectional.only(start: 8, end: 10, top: 8, bottom: 8),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, FeedRhythm.tabScrollTailPadding),
              child: Builder(
                builder: (context) {
                  final visible =
                      shelfSeriesVisibleForBrandFilter(snap.shelfSeries, _brandFilterId);
                  final scheme = Theme.of(context).colorScheme;
                  final textTheme = Theme.of(context).textTheme;
                  if (visible.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
                      child: Text(
                        'Nothing on your shelf for this brand yet.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                          height: 1.4,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final s in visible)
                        SeriesShelfCard(
                          series: s,
                          progress: progressForSeries(s, snap.figureStates),
                          figureStates: snap.figureStates,
                          onOpen: () => _openFiguresSheet(context, s.id),
                          onRemove: () => _confirmRemoveSeries(context, s.id, s.name),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
