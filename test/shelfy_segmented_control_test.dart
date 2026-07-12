import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/shared/widgets/shelfy_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

enum _DemoSegment { a, b, c }

void main() {
  testWidgets('renders segments and reports selection changes', (tester) async {
    _DemoSegment selected = _DemoSegment.a;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ShelfySegmentedControl<_DemoSegment>(
                value: selected,
                onChanged: (next) => setState(() => selected = next),
                segments: const [
                  ShelfySegment(
                    value: _DemoSegment.a,
                    label: 'One',
                    icon: Icons.looks_one_rounded,
                  ),
                  ShelfySegment(
                    value: _DemoSegment.b,
                    label: 'Two',
                    icon: Icons.looks_two_rounded,
                  ),
                  ShelfySegment(
                    value: _DemoSegment.c,
                    label: 'Three',
                    icon: Icons.looks_3_rounded,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('shelfy_segmented_control')), findsOneWidget);
    expect(find.byType(SegmentedButton<_DemoSegment>), findsNothing);
    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsOneWidget);
    expect(find.text('Three'), findsOneWidget);

    await tester.tap(find.text('Two'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));
    expect(selected, _DemoSegment.b);

    await tester.tap(find.text('Three'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));
    expect(selected, _DemoSegment.c);
  });

  testWidgets('centers icon and label as one group', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ShelfySegmentedControl<_DemoSegment>(
            value: _DemoSegment.a,
            onChanged: (_) {},
            segments: const [
              ShelfySegment(
                value: _DemoSegment.a,
                label: 'Shelf',
                icon: Icons.grid_view_rounded,
              ),
              ShelfySegment(
                value: _DemoSegment.b,
                label: 'Insights',
                icon: Icons.auto_awesome_rounded,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final labelCenter = tester.getCenter(find.text('Shelf'));
    final iconCenter = tester.getCenter(find.byIcon(Icons.grid_view_rounded));
    // Icon sits to the left of the label; both share a vertical center.
    expect(iconCenter.dx, lessThan(labelCenter.dx));
    expect(iconCenter.dy, closeTo(labelCenter.dy, 1.5));
  });
}
