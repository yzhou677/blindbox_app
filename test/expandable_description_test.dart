import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/market/widgets/expandable_description.dart';
import 'package:blindbox_app/features/market/widgets/listing_description_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bodyStyle = TextStyle(fontSize: 14, height: 1.35);

  Widget wrap(Widget child, {Brightness brightness = Brightness.light}) {
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );
  }

  testWidgets('short text hides Read more', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ExpandableDescription(
          text: 'Sealed blind box. Ships fast.',
          style: bodyStyle,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Read more'), findsNothing);
    expect(find.text('Show less'), findsNothing);
    expect(find.text('Sealed blind box. Ships fast.'), findsOneWidget);
  });

  testWidgets('long text expands and collapses inline', (tester) async {
    final long = List.filled(90, 'collectible').join(' ');

    await tester.pumpWidget(
      wrap(
        ExpandableDescription(text: long, style: bodyStyle),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Read more'), findsOneWidget);

    await tester.tap(find.text('Read more'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    expect(find.text('Show less'), findsOneWidget);
    expect(find.text('Read more'), findsNothing);

    await tester.ensureVisible(find.text('Show less'));
    await tester.tap(find.text('Show less'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    expect(find.text('Read more'), findsOneWidget);
    expect(find.text('Show less'), findsNothing);
  });

  testWidgets('expanded state persists until collapse', (tester) async {
    final long = List.filled(90, 'vinyl').join(' ');

    await tester.pumpWidget(
      wrap(ExpandableDescription(text: long, style: bodyStyle)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read more'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -120));
    await tester.pump();

    expect(find.text('Show less'), findsOneWidget);
  });

  testWidgets('ListingDescriptionSection hides for null and empty', (tester) async {
    await tester.pumpWidget(
      wrap(const ListingDescriptionSection(description: null)),
    );
    await tester.pumpAndSettle();
    expect(find.text('About this listing'), findsNothing);

    await tester.pumpWidget(
      wrap(const ListingDescriptionSection(description: '   ')),
    );
    await tester.pumpAndSettle();
    expect(find.text('About this listing'), findsNothing);

    await tester.pumpWidget(
      wrap(const ListingDescriptionSection(description: '<p></p>')),
    );
    await tester.pumpAndSettle();
    expect(find.text('About this listing'), findsNothing);
  });

  testWidgets('ListingDescriptionSection renders sanitized HTML copy', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ListingDescriptionSection(
          description: '<p>Pop Mart <b>Labubu</b> &mdash; sealed</p>',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('About this listing'), findsOneWidget);
    expect(find.text('Pop Mart Labubu — sealed'), findsOneWidget);
  });

  testWidgets('dark theme keeps toggle readable', (tester) async {
    final long = List.filled(90, 'figure').join(' ');

    await tester.pumpWidget(
      wrap(
        ExpandableDescription(text: long, style: bodyStyle),
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Read more'), findsOneWidget);
    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.style?.foregroundColor, isNotNull);
  });
}
