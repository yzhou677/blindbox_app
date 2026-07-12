import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetypes.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_avatar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Debug-only grid of all Collector Type mascots.
///
/// Open via long-press on the Insights screen title, or
/// `context.push('/debug/collector-types')`.
class CollectorTypeMascotGalleryScreen extends StatelessWidget {
  const CollectorTypeMascotGalleryScreen({super.key});

  static const routePath = '/debug/collector-types';

  @override
  Widget build(BuildContext context) {
    assert(kDebugMode, 'Mascot gallery is debug-only');
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final types = CollectorTypeArchetypes.all;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collector Type mascots'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal,
          AppSpacing.lg,
          AppSpacing.pageHorizontal,
          AppSpacing.xl,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 16,
          childAspectRatio: 0.78,
        ),
        itemCount: types.length,
        itemBuilder: (context, index) {
          final archetype = types[index];
          final avatar = CollectorTypeAvatar.tryBuild(
            id: archetype.id,
            size: 120,
            semanticLabel: archetype.displayName,
          );
          return Column(
            children: [
              if (avatar != null)
                avatar
              else
                SizedBox(
                  width: 120,
                  height: 120,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: archetype
                          .accentFor(Theme.of(context).brightness)
                          .withValues(alpha: 0.18),
                    ),
                    child: Icon(
                      archetype.icon ?? Icons.auto_awesome_outlined,
                      size: 40,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Text(
                archetype.displayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: CollectibleTypography.shelfSeriesTitle(
                  textTheme,
                  scheme,
                ).copyWith(fontSize: 14),
              ),
            ],
          );
        },
      ),
    );
  }
}
