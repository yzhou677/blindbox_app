import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/collection_screen.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class EmptyTestCollectionNotifier extends CollectionNotifier {
  @override
  CollectionSnapshot build() => CollectionSnapshot.emptyTest();
}

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
    expect(find.text('Trending series'), findsOneWidget);
    expect(find.text('Skullpanda'), findsOneWidget);
  });

  testWidgets('Collection tab shows series-first shelf and summary', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BlindboxApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Collection'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('My collection'), findsWidgets);
    expect(find.text('OWNED'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Add line'), findsOneWidget);
    expect(find.text('The Other One'), findsOneWidget);
  });

  testWidgets('Market tab shows search and trending', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BlindboxApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Market'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Trending'), findsOneWidget);
    expect(find.text('Browse listings'), findsOneWidget);
    expect(find.text('Luna Astronaut'), findsWidgets);
  });

  testWidgets('Collection empty state is polished', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(EmptyTestCollectionNotifier.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CollectionScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Your shelf is waiting'), findsOneWidget);
    expect(find.text('Browse drops'), findsOneWidget);
  });
}
