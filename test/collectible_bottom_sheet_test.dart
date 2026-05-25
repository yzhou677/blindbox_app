import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolveCollectibleSheetExtents uses screen-height fractions', () {
    const open = 0.56;
    const minScreen = FeedRhythm.sheetMinScreenFraction;
    final extents = resolveCollectibleSheetExtents(
      openScreenFraction: open,
      minScreenFraction: minScreen,
      maxScreenFraction: open,
    );

    expect(extents.initialChildSize, open);
    expect(extents.maxChildSize, open);
    expect(extents.minChildSize, minScreen);
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
                      builder: (ctx, scroll) => CollectibleSheetScrollView(
                        controller: scroll,
                        slivers: const [
                          SliverToBoxAdapter(child: Text('Sheet body')),
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
    expect(find.byType(CollectibleSheetScrollView), findsOneWidget);
    expect(find.descendant(of: find.byType(DraggableScrollableSheet), matching: find.byType(Material)), findsOneWidget);

    final sheetMaterial = tester.widget<Material>(
      find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byType(Material),
      ).first,
    );
    expect(sheetMaterial.color, AppTheme.light().colorScheme.surface);
    expect(sheetMaterial.elevation, greaterThan(0));

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Sheet body'), findsNothing);
  });
}
