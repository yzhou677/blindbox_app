import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('showCollectibleBottomSheet sizes modal to heightFactor', (
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
    expect(find.byType(FractionallySizedBox), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsNothing);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Sheet body'), findsNothing);
  });
}
