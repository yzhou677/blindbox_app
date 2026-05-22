import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:blindbox_app/features/collection/presentation/figure_secret_rarity_style.dart';
import 'package:flutter/material.dart';

/// Collectible-style figure labels — add, remove, rename, secret + ratio.
class FigureNameChipsEditor extends StatelessWidget {
  const FigureNameChipsEditor({
    super.key,
    required this.figures,
    required this.onRemoveAt,
    required this.onEditAt,
    required this.addFieldController,
    required this.onAddSubmitted,
    required this.addFieldFocusNode,
    required this.onPickFigurePhoto,
    required this.onClearFigurePhoto,
    required this.onSecretChanged,
    required this.onRarityLabelChanged,
  });

  final List<CustomFigureDraft> figures;
  final ValueChanged<int> onRemoveAt;
  final ValueChanged<int> onEditAt;
  final TextEditingController addFieldController;
  final VoidCallback onAddSubmitted;
  final FocusNode addFieldFocusNode;
  final ValueChanged<int> onPickFigurePhoto;
  final ValueChanged<int> onClearFigurePhoto;
  final void Function(int index, bool isSecret) onSecretChanged;
  final void Function(int index, String? rarityLabel) onRarityLabelChanged;

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
            if (figures.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${figures.length}',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSecondaryContainer.withValues(alpha: 0.85),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Tap a name to edit. Use Secret for chase variants — add a ratio like 1:72 if you know it.',
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: figures.isEmpty
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
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < figures.length; i++)
                      _FigureDraftChip(
                        key: ValueKey('fig-draft-$i-${figures[i].displayName}'),
                        draft: figures[i],
                        onLabelTap: () => onEditAt(i),
                        onPickPhoto: () => onPickFigurePhoto(i),
                        onClearPhoto: () => onClearFigurePhoto(i),
                        onRemove: () => onRemoveAt(i),
                        onSecretChanged: (v) => onSecretChanged(i, v),
                        onRarityChanged: (v) => onRarityLabelChanged(i, v),
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
                  fillColor: scheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: scheme.primary.withValues(alpha: 0.55),
                      width: 1.4,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonal(
              onPressed: onAddSubmitted,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Icon(Icons.add_rounded, size: 22),
            ),
          ],
        ),
      ],
    );
  }
}

class _FigureDraftChip extends StatefulWidget {
  const _FigureDraftChip({
    super.key,
    required this.draft,
    required this.onLabelTap,
    required this.onPickPhoto,
    required this.onClearPhoto,
    required this.onRemove,
    required this.onSecretChanged,
    required this.onRarityChanged,
  });

  final CustomFigureDraft draft;
  final VoidCallback onLabelTap;
  final VoidCallback onPickPhoto;
  final VoidCallback onClearPhoto;
  final VoidCallback onRemove;
  final ValueChanged<bool> onSecretChanged;
  final ValueChanged<String> onRarityChanged;

  @override
  State<_FigureDraftChip> createState() => _FigureDraftChipState();
}

class _FigureDraftChipState extends State<_FigureDraftChip> {
  late final TextEditingController _rarityController;

  @override
  void initState() {
    super.initState();
    _rarityController = TextEditingController(
      text: widget.draft.rarityLabel ?? '',
    );
  }

  @override
  void didUpdateWidget(_FigureDraftChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.rarityLabel != widget.draft.rarityLabel &&
        _rarityController.text != (widget.draft.rarityLabel ?? '')) {
      _rarityController.text = widget.draft.rarityLabel ?? '';
    }
  }

  @override
  void dispose() {
    _rarityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasPhoto = widget.draft.localImageUri?.trim().isNotEmpty ?? false;
    final draft = widget.draft;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    var cardColor = scheme.surfaceContainerLow;
    if (draft.isSecret) {
      final ratioText = _rarityController.text.trim();
      final look = FigureSecretRarityStyle.resolve(
        isSecret: true,
        rarityLabel: ratioText.isNotEmpty ? ratioText : draft.rarityLabel,
        isDark: isDark,
      );
      if (look != null) {
        cardColor = look.cardTint(cardColor);
      }
    }

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onLabelTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasPhoto) ...[
                            Icon(
                              Icons.photo_rounded,
                              size: 17,
                              color: scheme.primary.withValues(alpha: 0.72),
                            ),
                            const SizedBox(width: 8),
                          ],
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 118),
                            child: Text(
                              draft.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.06,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.edit_outlined,
                            size: 13,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  tooltip: hasPhoto ? 'Change photo' : 'Add photo',
                  icon: Icon(
                    hasPhoto ? Icons.image_rounded : Icons.add_a_photo_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                  ),
                  onPressed: widget.onPickPhoto,
                ),
                if (hasPhoto) ...[
                  const SizedBox(width: 2),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 34,
                    ),
                    tooltip: 'Remove photo',
                    icon: Icon(
                      Icons.restart_alt_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                    onPressed: widget.onClearPhoto,
                  ),
                ],
                const SizedBox(width: 2),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
                  ),
                  onPressed: widget.onRemove,
                  tooltip: 'Remove',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Secret',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(width: 2),
                Transform.scale(
                  scale: 0.78,
                  alignment: Alignment.centerLeft,
                  child: Switch(
                    value: draft.isSecret,
                    onChanged: widget.onSecretChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            if (draft.isSecret) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: 156,
                child: TextField(
                  controller: _rarityController,
                  onChanged: (v) {
                    setState(() {});
                    widget.onRarityChanged(v);
                  },
                  textInputAction: TextInputAction.done,
                  style: textTheme.labelMedium,
                  decoration: InputDecoration(
                    hintText: 'e.g. 1:72',
                    isDense: true,
                    filled: true,
                    fillColor: scheme.surface.withValues(
                      alpha: isDark ? 0.35 : 0.55,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.32),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
