import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/market/widgets/market_browse_session_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MarketBrowseSliverResultsSkeleton', () {
    testWidgets('lays out inside SliverFillRemaining without viewport intrinsics error', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: const MarketBrowseSliverResultsSkeleton(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(ListView), findsNothing);
      expect(find.byType(MarketBrowseSliverResultsSkeleton), findsOneWidget);
    });
  });

  group('MarketBrowseResultsSkeleton (search)', () {
    testWidgets('uses ListView for scrollable constrained viewport', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              height: 280,
              child: const MarketBrowseResultsSkeleton(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
