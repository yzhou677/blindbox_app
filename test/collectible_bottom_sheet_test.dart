import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolveCollectibleSheetDragSizes fills height-capped host at rest', () {
    const open = 0.56;
    const minScreen = FeedRhythm.sheetMinScreenFraction;
    final sizes = resolveCollectibleSheetDragSizes(heightFactor: open);

    expect(sizes.initialChildSize, 1.0);
    expect(sizes.maxChildSize, 1.0);
    expect(sizes.minChildSize, closeTo(minScreen / open, 0.01));
  });

  testWidgets('showCollectibleBottomSheet uses linked DraggableScrollableSheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showCollectibleBottomSheet<void>(
                      context: context,
                      heightFraction: 0.5,
                      builder: (ctx, scroll) => ListView(
                        controller: scroll,
                        physics: collectibleSheetScrollPhysics(),
                        children: const [
                          Text('Sheet body'),
                        ],
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Sheet body'), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsWidgets);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Sheet body'), findsNothing);
  });
}
