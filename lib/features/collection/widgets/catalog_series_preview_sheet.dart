import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/figure_secret_rarity_style.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:flutter/material.dart';

/// Read-only catalog lineup preview before adding a series to the shelf.
///
/// Mirrors the cozy layout of [SeriesFiguresSheet] without shelf state cycling.
/// Fills the host sheet height with a pinned bottom CTA tray.
class CatalogSeriesPreviewSheet extends StatelessWidget {
  const CatalogSeriesPreviewSheet({
    super.key,
    required this.series,
    required this.onAdd,
  });

  final CatalogSeries series;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final chaseCount = series.figures.where((f) => f.isSecret).length;
    final countLine = series.figureCount == 1 ? '1 figure' : '${series.figureCount} figures';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  series.ipName,
                  style: textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  series.name,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.22,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${series.brand} · $countLine${chaseCount > 0 ? ' · chase in lineup' : ''}',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.86),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: series.figures.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final f = series.figures[i];
              return _PreviewFigureRow(figure: f, accent: series.shelfAccent);
            },
          ),
        ),
        Material(
          color: scheme.surface,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.28),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: FilledButton(
                  onPressed: () {
                    onAdd();
                    Navigator.of(context).pop();
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Add to shelf'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewFigureRow extends StatelessWidget {
  const _PreviewFigureRow({required this.figure, required this.accent});

  final CatalogFigure figure;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secretLook = FigureSecretRarityStyle.resolve(
      isSecret: figure.isSecret,
      rarityLabel: figure.isSecret ? figure.rarity : null,
      isDark: isDark,
    );
    final rowBase = scheme.surfaceContainerLow;
    final rowColor = secretLook != null ? secretLook.cardTint(rowBase) : rowBase;

    return Material(
      color: rowColor,
      borderRadius: BorderRadius.circular(16),
      shadowColor: secretLook?.accent.withValues(alpha: 0.12),
      elevation: secretLook != null ? 0.5 : 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: (figure.catalogImageKey?.trim().isNotEmpty ?? false)
                  ? CatalogImageFromKey(
                      imageKey: figure.catalogImageKey!,
                      name: figure.name,
                      seedKey: figure.templateFigureId,
                      isSecret: figure.isSecret,
                      compact: true,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(12),
                    )
                  : ColoredBox(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    figure.name,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    figure.rarity,
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
            if (figure.isSecret)
              Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: Color.lerp(accent, scheme.tertiary, 0.5)!.withValues(alpha: 0.88),
              ),
          ],
        ),
      ),
    );
  }
}
