import 'package:blindbox_app/features/collection/data/mock_owned_collection.dart';
import 'package:blindbox_app/features/collection/widgets/collection_empty_state.dart';
import 'package:blindbox_app/features/collection/widgets/collection_summary_section.dart';
import 'package:blindbox_app/features/collection/widgets/collection_shelf_grid.dart';
import 'package:blindbox_app/models/owned_collectible.dart';
import 'package:flutter/material.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key, this.items});

  /// When null, uses [mockOwnedCollection]. Pass `[]` in tests to verify empty UI.
  final List<OwnedCollectible>? items;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> with SingleTickerProviderStateMixin {
  AnimationController? _intro;
  List<CurvedAnimation> _appear = [];

  List<OwnedCollectible> get _entries => widget.items ?? mockOwnedCollection;

  @override
  void initState() {
    super.initState();
    _syncIntro();
  }

  @override
  void didUpdateWidget(covariant CollectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _disposeIntro();
      _syncIntro();
    }
  }

  void _syncIntro() {
    final entries = _entries;
    if (entries.isEmpty) return;

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 880),
    );

    _appear = List.generate(entries.length, (i) {
      final start = (i * 0.052).clamp(0.0, 0.72);
      final end = (0.38 + i * 0.052).clamp(0.22, 1.0);
      return CurvedAnimation(
        parent: _intro!,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _intro?.forward();
    });
  }

  void _disposeIntro() {
    for (final a in _appear) {
      a.dispose();
    }
    _appear = [];
    _intro?.dispose();
    _intro = null;
  }

  @override
  void dispose() {
    _disposeIntro();
    super.dispose();
  }

  CollectionShelfStats _statsFor(List<OwnedCollectible> items) {
    final totalPieces = items.fold<int>(0, (sum, e) => sum + e.quantity);
    final seriesCount = items.map((e) => e.collectible.series).toSet().length;
    return CollectionShelfStats(
      totalPieces: totalPieces,
      uniqueFigures: items.length,
      seriesCount: seriesCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final entries = _entries;

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
          if (entries.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Text(
                  'Pieces you love, beautifully arranged.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                    height: 1.28,
                  ),
                ),
              ),
            ),
          if (entries.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: CollectionEmptyState(),
            )
          else ...[
            SliverToBoxAdapter(
              child: CollectionSummarySection(stats: _statsFor(entries)),
            ),
            CollectionShelfGrid(
              items: entries,
              appearAnimations: _appear,
            ),
          ],
        ],
      ),
    );
  }
}
