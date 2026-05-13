import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:blindbox_app/features/home/widgets/latest_drops_section.dart';
import 'package:blindbox_app/features/home/widgets/trending_series_section.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: false,
            floating: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 52,
            backgroundColor: scheme.surface,
            surfaceTintColor: scheme.surfaceTint.withValues(alpha: 0.32),
            centerTitle: false,
            titleSpacing: 20,
            title: Text(
              'Discover',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: -0.22,
                height: 1.18,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LatestDropsSection(items: mockLatestDrops),
                  const SizedBox(height: 36),
                  const TrendingSeriesSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
