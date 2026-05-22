import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/presentation/collection_modal_overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dismissCollectionModalOverlays closes open bottom sheet', (
    tester,
  ) async {
    late BuildContext hostContext;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            hostContext = context;
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showCollectionModalBottomSheet<void>(
                      context: context,
                      builder: (ctx) => const SizedBox(
                        height: 200,
                        child: Center(child: Text('Add a series')),
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
    expect(find.text('Add a series'), findsOneWidget);

    Navigator.of(hostContext).pop();
    await tester.pumpAndSettle();
    expect(find.text('Add a series'), findsNothing);
  });
}
