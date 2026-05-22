import 'package:blindbox_app/core/theme/app_radii.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'package:flutter/material.dart';

/// Series cover — tap to add or replace from the gallery.
class CustomSeriesCoverSlot extends StatelessWidget {
  const CustomSeriesCoverSlot({
    super.key,
    required this.imagePath,
    required this.onReplaceTap,
    required this.onClearTap,
  });

  final String? imagePath;
  final VoidCallback onReplaceTap;
  final VoidCallback onClearTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final has = imagePath != null && imagePath!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cover',
          style: CollectibleTypography.figureMeta(textTheme, scheme).copyWith(
            fontSize: 12,
            letterSpacing: 0.14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: scheme.surfaceContainerLow.withValues(alpha: 0.7),
          borderRadius: AppRadii.cardRadius,
          child: InkWell(
            onTap: onReplaceTap,
            borderRadius: AppRadii.cardRadius,
            child: Ink(
              height: 132,
              decoration: BoxDecoration(
                borderRadius: AppRadii.cardRadius,
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.22),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (has)
                    Positioned.fill(
                      child: CollectibleThumbImage(
                        imageRef: imagePath,
                        name: 'Cover',
                        seedKey: 'custom-cover',
                        fit: BoxFit.cover,
                        borderRadius: AppRadii.cardRadius,
                      ),
                    ),
                  if (!has)
                    Center(
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 30,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.38),
                      ),
                    ),
                  if (has)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Material(
                        color: scheme.surface.withValues(alpha: 0.9),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Remove cover',
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          onPressed: onClearTap,
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(6),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
