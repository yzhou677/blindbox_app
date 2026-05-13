import 'package:blindbox_app/features/home/data/mock_trending_series.dart';
import 'package:blindbox_app/features/home/widgets/trending_series_capsule.dart';
import 'package:flutter/material.dart';

/// Horizontal IP / series rail — softer and more compact than Latest Drops.
class TrendingSeriesSection extends StatelessWidget {
  const TrendingSeriesSection({super.key});

  static const double _railHeight = kTrendingSeriesCapsuleHeight + 10;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trending series',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.12,
                  height: 1.22,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Browse character worlds and IPs—cozy universe hopping.',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                  height: 1.38,
                  letterSpacing: 0.06,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: _railHeight,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: mockTrendingSeries.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              return TrendingSeriesCapsule(series: mockTrendingSeries[index]);
            },
          ),
        ),
      ],
    );
  }
}
