import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/add_custom_series_sheet.dart';
import 'package:blindbox_app/features/collection/widgets/collection_empty_state.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:blindbox_app/features/collection/widgets/collection_warm_start_banner.dart';
import 'package:blindbox_app/features/collection/widgets/series_figures_sheet.dart';
import 'package:blindbox_app/features/collection/widgets/series_shelf_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
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

  Future<void> _confirmRemoveCustom(BuildContext context, String id, String name) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Remove line?'),
          content: Text('“$name” will leave your shelf (mock data only).'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
          ],
        );
      },
    );
    if (go == true && context.mounted) {
      ref.read(collectionNotifierProvider.notifier).removeCustomSeries(id);
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
      builder: (ctx) => AddCustomSeriesSheet(
        onSubmit: ({
          required String seriesName,
          String? brand,
          String? ipDisplayName,
          required List<String> figureNames,
          String? notes,
        }) {
          ref.read(collectionNotifierProvider.notifier).addCustomSeries(
                seriesName: seriesName,
                brand: brand,
                ipDisplayName: ipDisplayName,
                figureNames: figureNames,
                notes: notes,
              );
        },
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
        backgroundColor: scheme.surface,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar.large(
              floating: false,
              pinned: false,
              backgroundColor: scheme.surface,
              surfaceTintColor: scheme.surfaceTint.withValues(alpha: 0.45),
              title: Text(
                'My shelf',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.48,
                  height: 1.12,
                ),
              ),
            ),
            const SliverFillRemaining(
              hasScrollBody: false,
              child: CollectionEmptyState(),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            floating: false,
            pinned: false,
            backgroundColor: scheme.surface,
            surfaceTintColor: scheme.surfaceTint.withValues(alpha: 0.45),
            title: Text(
              'My shelf',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.48,
                height: 1.12,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Text(
                'IP → series → figures. Track pulls and wishes with real names.',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                  height: 1.28,
                ),
              ),
            ),
          ),
          if (snap.isWarmStart)
            const SliverToBoxAdapter(child: CollectionWarmStartBanner()),
          SliverToBoxAdapter(
            child: CollectionSummarySection(stats: CollectionAggregateStats.fromSnapshot(snap)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                'Official series',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.12,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (final s in snap.allOfficialSeries)
                    SeriesShelfCard(
                      series: s,
                      progress: progressForSeries(s, snap.figureStates),
                      onOpen: () => _openFiguresSheet(context, s.id),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your lines',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.12,
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _openAddCustom(context),
                    child: const Text('Add line'),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
              child: Column(
                children: [
                  for (final s in snap.customSeries)
                    SeriesShelfCard(
                      series: s,
                      progress: progressForSeries(s, snap.figureStates),
                      onOpen: () => _openFiguresSheet(context, s.id),
                      onRemove: () => _confirmRemoveCustom(context, s.id, s.name),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
