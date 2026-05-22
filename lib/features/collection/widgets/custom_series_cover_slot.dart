import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'package:flutter/material.dart';

/// Soft shelf-style control: tap to add/replace a series cover from the gallery.
class CustomSeriesCoverSlot extends StatelessWidget {
  const CustomSeriesCoverSlot({
    super.key,
    required this.imagePath,
    required this.onReplaceTap,
    required this.onClearTap,
  });

  /// Local path from [ImagePicker] or `null` when unset.
  final String? imagePath;
  final VoidCallback onReplaceTap;
  final VoidCallback onClearTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final has = imagePath != null && imagePath!.trim().isNotEmpty;

    final radius = BorderRadius.circular(20);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cover (optional)',
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.04,
            color: scheme.onSurface.withValues(alpha: 0.88),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: scheme.surfaceContainerLow,
          borderRadius: radius,
          child: InkWell(
            onTap: onReplaceTap,
            borderRadius: radius,
            child: Ink(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.38),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.surfaceContainerLow,
                    Color.lerp(
                      scheme.surfaceContainerLow,
                      scheme.secondaryContainer,
                      0.22,
                    )!,
                  ],
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
                        borderRadius: radius,
                      ),
                    ),
                  if (!has)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 32,
                            color: scheme.primary.withValues(alpha: 0.72),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              'Tap to choose a cosy cover photo',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.88,
                                ),
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (has)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Material(
                        color: scheme.surface.withValues(alpha: 0.92),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Remove cover',
                          icon: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: scheme.onSurfaceVariant,
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
