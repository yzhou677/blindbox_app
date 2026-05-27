import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/collection_series_identity.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/home/domain/series_release.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How [SaveSeriesReleaseButton] presents on Home (icon on cards vs filled CTA on detail).
enum SeriesReleaseShelfCtaVariant {
  /// Compact icon control for horizontal rail cards.
  icon,

  /// Compact filled control for release detail (meaning in the label).
  filled,
}

/// Adds or removes the full **series** from a Home release on the shelf.
class SaveSeriesReleaseButton extends ConsumerStatefulWidget {
  const SaveSeriesReleaseButton({
    super.key,
    required this.release,
    this.variant = SeriesReleaseShelfCtaVariant.icon,
  });

  final SeriesRelease release;
  final SeriesReleaseShelfCtaVariant variant;

  @override
  ConsumerState<SaveSeriesReleaseButton> createState() => _SaveSeriesReleaseButtonState();
}

class _SaveSeriesReleaseButtonState extends ConsumerState<SaveSeriesReleaseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  String get _catalogKey => 'drop-${widget.release.dropId}';

  CollectionSeriesOwnershipMatch _ownership(CollectionSnapshot snap) {
    return resolveCollectionSeriesOwnership(
      snapshot: snap,
      catalogTemplateId: _catalogKey,
      alternateCatalogTemplateIds: [widget.release.dropId],
      seriesName: widget.release.seriesName,
      brandName: widget.release.brand,
      taxonomyBrandId: widget.release.taxonomyBrandId,
      taxonomyIpId: widget.release.taxonomyIpId,
    );
  }

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _runPulse() {
    _pulse.forward(from: 0).then((_) {
      if (mounted) _pulse.reverse();
    });
  }

  void _addToShelf() {
    ref
        .read(collectionNotifierProvider.notifier)
        .addSeriesFromRelease(widget.release);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _runPulse();
    });
  }

  Future<void> _confirmRemoveFromShelf() async {
    final name = widget.release.seriesName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove series?'),
        content: Text('“$name” will leave your shelf.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final match = ref.read(
      collectionNotifierProvider.select(
        (s) => _ownership(s),
      ),
    );
    final removableKey = match.matchedCatalogTemplateId ?? _catalogKey;
    ref
        .read(collectionNotifierProvider.notifier)
        .removeSeriesByCatalogTemplate(removableKey);
  }

  void _showOwnedManagedElsewhereHint() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This series is already in your collection. Manage it from My collection.',
        ),
      ),
    );
  }

  void _handleTap() {
    final match = ref.read(
      collectionNotifierProvider.select(
        (s) => _ownership(s),
      ),
    );
    if (match.owned) {
      if (match.removableViaReleaseCta) {
        _confirmRemoveFromShelf();
      } else {
        _showOwnedManagedElsewhereHint();
      }
    } else {
      _addToShelf();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final match = ref.watch(
      collectionNotifierProvider.select(
        (s) => _ownership(s),
      ),
    );
    final onShelf = match.owned;

    final scale = Tween<double>(begin: 1.0, end: 1.14).evaluate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeOutCubic),
    );

    if (widget.variant == SeriesReleaseShelfCtaVariant.filled) {
      final filledStyle = FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        elevation: 0,
        shadowColor: scheme.shadow.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.15,
            ),
      );

      return Transform.scale(
        scale: scale,
        alignment: Alignment.centerLeft,
        child: onShelf
            ? FilledButton.tonal(
                onPressed: match.removableViaReleaseCta ? _handleTap : null,
                style: filledStyle.copyWith(
                  foregroundColor: WidgetStatePropertyAll(
                    scheme.onSurfaceVariant.withValues(alpha: 0.85),
                  ),
                ),
                child: const Text('In your collection'),
              )
            : FilledButton.icon(
                onPressed: _handleTap,
                icon: const Icon(Icons.add_rounded, size: 21),
                label: const Text('Add to my collection'),
                style: filledStyle,
              ),
      );
    }

    return Transform.scale(
      scale: scale,
      child: IconButton(
        tooltip: onShelf ? 'Remove from collection' : 'Add to my collection',
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        onPressed: _handleTap,
        icon: Icon(
          onShelf ? Icons.bookmark_added_rounded : Icons.add_circle_outline_rounded,
          size: 22,
          color: onShelf
              ? scheme.primary.withValues(alpha: 0.45)
              : scheme.primary.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}
