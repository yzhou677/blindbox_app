import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/insights/widgets/collector_type_ambient_glow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('builds and animates without error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: CollectorTypeAmbientGlow(
            child: SizedBox(width: 200, height: 120),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CollectorTypeAmbientGlow), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
