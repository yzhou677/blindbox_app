import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_brand_donut.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('empty breakdown shows placeholder', (tester) async {
    await tester.pumpWidget(
      wrap(const CollectorTypeBrandDonut(brandBreakdown: {})),
    );
    await tester.pump();
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('single brand renders CustomPaint without caption', (tester) async {
    await tester.pumpWidget(
      wrap(
        const CollectorTypeBrandDonut(
          brandBreakdown: {'POP MART': 2},
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('POP MART'), findsNothing);
  });

  testWidgets('multi brand renders CustomPaint', (tester) async {
    await tester.pumpWidget(
      wrap(
        const CollectorTypeBrandDonut(
          brandBreakdown: {
            'POP MART': 2,
            'Finding Unicorn': 1,
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
