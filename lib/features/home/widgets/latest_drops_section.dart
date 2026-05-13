import 'package:blindbox_app/features/home/widgets/latest_drop_card.dart';
import 'package:blindbox_app/models/collectible.dart';
import 'package:flutter/material.dart';

class LatestDropsSection extends StatelessWidget {
  const LatestDropsSection({super.key, required this.items});

  final List<Collectible> items;

  /// Card + polaroid mat + chip + date pill + breathing room.
  static const double _railHeight = 468;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Latest drops',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.12,
                        height: 1.22,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'New',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Fresh picks for your shelf — soft launches, big smiles.',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                  height: 1.38,
                  letterSpacing: 0.08,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: _railHeight,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 20),
            itemBuilder: (context, index) => LatestDropCard(collectible: items[index]),
          ),
        ),
      ],
    );
  }
}
