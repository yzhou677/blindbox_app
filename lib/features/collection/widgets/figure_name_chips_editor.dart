import 'package:flutter/material.dart';

/// Collectible-style figure labels — add, remove, rename without a multiline form.
class FigureNameChipsEditor extends StatelessWidget {
  const FigureNameChipsEditor({
    super.key,
    required this.names,
    required this.onRemoveAt,
    required this.onEditAt,
    required this.addFieldController,
    required this.onAddSubmitted,
    required this.addFieldFocusNode,
  });

  final List<String> names;
  final ValueChanged<int> onRemoveAt;
  final ValueChanged<int> onEditAt;
  final TextEditingController addFieldController;
  final VoidCallback onAddSubmitted;
  final FocusNode addFieldFocusNode;

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
                        onTap: () => onEditAt(i),
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
    required this.onTap,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8, right: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
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
              const SizedBox(width: 4),
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
        ),
      ),
    );
  }
}
