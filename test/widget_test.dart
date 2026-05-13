import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/collection_screen.dart';
import 'package:blindbox_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App shell shows Home tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BlindboxApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Discover'), findsWidgets);
    expect(find.text('Latest drops'), findsOneWidget);
    expect(find.text('Luna Astronaut'), findsOneWidget);
  });

  testWidgets('Collection tab shows shelf grid and summary', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BlindboxApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Collection'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('My shelf'), findsWidgets);
    expect(find.text('PIECES'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('Moon Mischief'), findsWidgets);
  });

  testWidgets('Collection empty state is polished', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CollectionScreen(items: []),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Your shelf is waiting'), findsOneWidget);
    expect(find.text('Browse drops'), findsOneWidget);
  });
}
