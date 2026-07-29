import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/core/theme/shelfy_symbols.dart';
import 'package:blindbox_app/features/collection/presentation/collection_modal_overlays.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_layout.dart';
import 'package:blindbox_app/features/collection/presentation/collection_vocabulary.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_sheet_chrome.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Opens a compact layout picker; returns the selected layout or `null`.
Future<CollectionShelfLayout?> showCollectionShelfLayoutSheet({
  required BuildContext context,
  required CollectionShelfLayout selected,
}) {
  return showCollectionModalBottomSheet<CollectionShelfLayout>(
    context: context,
    // Compact host — content is short; avoid a tall empty sheet.
    heightFraction: 0.38,
    builder: (context, scrollController) {
      return _CollectionShelfLayoutSheet(
        selected: selected,
        scrollController: scrollController,
      );
    },
  );
}

class _CollectionShelfLayoutSheet extends StatelessWidget {
  const _CollectionShelfLayoutSheet({
    required this.selected,
    required this.scrollController,
  });

  final CollectionShelfLayout selected;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Horizontal + safe bottom from insets; body owns title→content gap only.
    return CollectibleSheetInsets(
      extraBottom: 0,
      child: CollectibleSheetScrollView(
        controller: scrollController,
        header: const CollectibleSheetChrome(
          editorialTitle: CollectionVocabulary.layoutMenuTitle,
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: FeedRhythm.sheetTitleToBody,
                bottom: FeedRhythm.sheetBodyBottomInset,
              ),
              child: Column(
                children: [
                  for (final layout in CollectionShelfLayout.values)
                    _LayoutOptionRow(
                      layout: layout,
                      selected: layout == selected,
                      scheme: scheme,
                      textTheme: textTheme,
                      onTap: () => Navigator.of(context).pop(layout),
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

class _LayoutOptionRow extends StatelessWidget {
  const _LayoutOptionRow({
    required this.layout,
    required this.selected,
    required this.scheme,
    required this.textTheme,
    required this.onTap,
  });

  final CollectionShelfLayout layout;
  final bool selected;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  static const double _rowMinHeight = 52;
  static const double _iconLabelGap = AppSpacing.md; // 12

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('collection_layout_option_${layout.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _rowMinHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Icon(
                  layout.icon,
                  size: AppIconSizes.toolbar,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: _iconLabelGap),
                Expanded(
                  child: Text(
                    layout.menuLabel,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Symbols.check_rounded, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact toolbar control showing the active layout icon.
class CollectionShelfLayoutControl extends StatelessWidget {
  const CollectionShelfLayoutControl({
    super.key,
    required this.layout,
    required this.onPressed,
  });

  final CollectionShelfLayout layout;
  final VoidCallback onPressed;

  /// Accessible minimum hit target (Material guidance).
  static const double minTapExtent = 48;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: layout.semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('collection_shelf_layout_control'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: minTapExtent,
            height: minTapExtent,
            // Glyph sits on the trailing edge so Layout reads next to Sort.
            child: Align(
              alignment: Alignment.centerRight,
              child: Icon(
                layout.icon,
                size: AppIconSizes.metadata,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filtered-empty shelf message with clear-filters action.
class CollectionShelfFilteredEmptyState extends StatelessWidget {
  const CollectionShelfFilteredEmptyState({
    super.key,
    required this.onClearFilters,
    this.message = CollectionVocabulary.filteredEmptyTitle,
  });

  final VoidCallback onClearFilters;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.lg,
        AppSpacing.pageHorizontal,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
              height: 1.4,
            ),
          ),
          const SizedBox(height: FeedRhythm.sheetLabelToControl),
          TextButton(
            key: const Key('collection_clear_filters_cta'),
            onPressed: onClearFilters,
            child: Text(
              CollectionVocabulary.filteredEmptyAction,
              style: CollectibleTypography.shelfFigureSheetSectionLabel(
                textTheme,
                scheme,
              ).copyWith(color: scheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
