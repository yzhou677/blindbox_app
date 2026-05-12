import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:blindbox_app/features/home/widgets/latest_drops_section.dart';
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
          SliverAppBar.large(
            floating: false,
            pinned: false,
            backgroundColor: scheme.surface,
            surfaceTintColor: scheme.surfaceTint.withValues(alpha: 0.5),
            title: Text(
              'Discover',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                height: 1.12,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 36),
              child: LatestDropsSection(items: mockLatestDrops),
            ),
          ),
        ],
      ),
    );
  }
}
