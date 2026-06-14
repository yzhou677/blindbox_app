import 'package:blindbox_app/features/market_intel/application/market_snapshot_providers.dart';
import 'package:blindbox_app/features/market_intel/dev/market_snapshot_dev_cases.dart';
import 'package:blindbox_app/features/market_intel/dev/market_snapshot_dev_config.dart';
import 'package:blindbox_app/features/market_intel/widgets/market_snapshot_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// DEV ONLY — temporary screen to validate Firestore → repository → provider → UI.
///
/// Launch with: `flutter run --dart-define=MARKET_SNAPSHOT_DEV=true`
/// Remove before production release. See tools/market_intel/DEV_VALIDATION.md.
class MarketSnapshotDevScreen extends ConsumerWidget {
  const MarketSnapshotDevScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Snapshot Dev'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              for (final testCase in marketSnapshotDevCases) {
                ref.invalidate(marketSnapshotProvider(testCase.figureId));
              }
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _DevBanner(),
          const SizedBox(height: 16),
          for (final testCase in marketSnapshotDevCases) ...[
            _MarketSnapshotDevCaseCard(testCase: testCase),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _DevBanner extends StatelessWidget {
  const _DevBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          kMarketSnapshotDevLive
              ? 'DEV ONLY — live Firestore reads. '
                  'Seed with tools/market_intel/push_market_snapshots_dev.mjs '
                  'then verify Cases A/B/C below.'
              : 'DEV ONLY — using in-memory mock repository. '
                  'Remove --dart-define=MARKET_SNAPSHOT_DEV_LIVE=false to use Firestore.',
        ),
      ),
    );
  }
}

class _MarketSnapshotDevCaseCard extends ConsumerWidget {
  const _MarketSnapshotDevCaseCard({required this.testCase});

  final MarketSnapshotDevCase testCase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnapshot = ref.watch(marketSnapshotProvider(testCase.figureId));
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(testCase.label, style: textTheme.titleSmall),
            const SizedBox(height: 8),
            Text('Figure id: ${testCase.figureId}', style: textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              'Expected: ${testCase.expectedSummary}',
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            asyncSnapshot.when(
              loading: () => const Text('Provider: loading…'),
              error: (error, _) => Text('Provider: error — $error'),
              data: (snapshot) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Result: ${describeMarketSnapshot(snapshot)}'),
                    if (snapshot != null) ...[
                      const SizedBox(height: 12),
                      MarketSnapshotBadge(snapshot: snapshot),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
