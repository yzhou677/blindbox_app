import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/shared/widgets/collectible_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dense header preserves copy and uses tighter title gap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: CollectibleSectionHeader(
            title: 'Latest drops',
            subtitle: 'Fresh series launches',
            dense: true,
          ),
        ),
      ),
    );

    final header = tester.widget<CollectibleSectionHeader>(
      find.byType(CollectibleSectionHeader),
    );
    expect(header.dense, isTrue);
    expect(find.text('Latest drops'), findsOneWidget);
    expect(find.text('Fresh series launches'), findsOneWidget);

    // Dense uses sectionTitleToSubtitle - 3 (= 5).
    expect(
      find.descendant(
        of: find.byType(CollectibleSectionHeader),
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.height == 5,
        ),
      ),
      findsOneWidget,
    );
  });
}
