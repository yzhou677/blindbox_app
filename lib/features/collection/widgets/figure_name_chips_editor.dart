import 'package:flutter/material.dart';

/// Collectible-style figure labels — add, remove, rename without a multiline form.
class FigureNameChipsEditor extends StatelessWidget {
  const FigureNameChipsEditor({
    super.key,
    required this.names,
    required this.figureLocalUris,
    required this.onRemoveAt,
    required this.onEditAt,
    required this.addFieldController,
    required this.onAddSubmitted,
    required this.addFieldFocusNode,
    required this.onPickFigurePhoto,
    required this.onClearFigurePhoto,
  });

  final List<String> names;
  /// Parallel to [names]; same length when the parent keeps them in sync.
  final List<String?> figureLocalUris;
  final ValueChanged<int> onRemoveAt;
  final ValueChanged<int> onEditAt;
  final TextEditingController addFieldController;
  final VoidCallback onAddSubmitted;
  final FocusNode addFieldFocusNode;
  final ValueChanged<int> onPickFigurePhoto;
  final ValueChanged<int> onClearFigurePhoto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text.rich(
              TextSpan(
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.08,
                ),
                children: [
                  const TextSpan(text: 'Figures '),
                  TextSpan(
                    text: '*',
                    style: TextStyle(
                      color: scheme.error,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (names.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${names.length}',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSecondaryContainer.withValues(alpha: 0.85),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: names.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Name each pull — they’ll show up as little shelf tags.',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                      height: 1.35,
                    ),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < names.length; i++)
                      _FigureNameChip(
                        label: names[i],
                        hasPhoto: i < figureLocalUris.length &&
                            (figureLocalUris[i]?.trim().isNotEmpty ?? false),
                        onLabelTap: () => onEditAt(i),
                        onPickPhoto: () => onPickFigurePhoto(i),
                        onClearPhoto: () => onClearFigurePhoto(i),
                        onRemove: () => onRemoveAt(i),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: addFieldController,
                focusNode: addFieldFocusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onAddSubmitted(),
                decoration: InputDecoration(
                  hintText: 'Add a figure name',
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.55), width: 1.4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonal(
              onPressed: onAddSubmitted,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Icon(Icons.add_rounded, size: 22),
            ),
          ],
        ),
      ],
    );
  }
}

class _FigureNameChip extends StatelessWidget {
  const _FigureNameChip({
    required this.label,
    required this.hasPhoto,
    required this.onLabelTap,
    required this.onPickPhoto,
    required this.onClearPhoto,
    required this.onRemove,
  });

  final String label;
  final bool hasPhoto;
  final VoidCallback onLabelTap;
  final VoidCallback onPickPhoto;
  final VoidCallback onClearPhoto;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      borderRadius: BorderRadius.circular(999),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onLabelTap,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8, right: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasPhoto)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.photo_rounded,
                          size: 18,
                          color: scheme.primary.withValues(alpha: 0.78),
                        ),
                      ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.06,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 32),
            tooltip: hasPhoto ? 'Change photo' : 'Add photo',
            icon: Icon(
              hasPhoto ? Icons.image_rounded : Icons.add_a_photo_outlined,
              size: 18,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
            ),
            onPressed: onPickPhoto,
          ),
          if (hasPhoto)
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 32),
              tooltip: 'Remove photo',
              icon: Icon(
                Icons.restart_alt_rounded,
                size: 18,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
              ),
              onPressed: onClearPhoto,
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
            ),
            onPressed: onRemove,
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}
