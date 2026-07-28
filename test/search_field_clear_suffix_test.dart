import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/shared/widgets/search_field_clear_suffix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('clear suffix rebuilds only on empty/non-empty transitions', (
    tester,
  ) async {
    final controller = TextEditingController();
    SearchFieldClearSuffix.debugListenerFireCount = 0;
    SearchFieldClearSuffix.debugVisibilityRebuildCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SearchFieldClearSuffix(
            controller: controller,
            onClear: controller.clear,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byTooltip('Clear'), findsNothing);

    controller.text = 'a';
    await tester.pump();
    expect(find.byTooltip('Clear'), findsOneWidget);
    expect(SearchFieldClearSuffix.debugVisibilityRebuildCount, 1);

    controller.text = 'ab';
    await tester.pump();
    controller.text = 'abc';
    await tester.pump();
    expect(SearchFieldClearSuffix.debugVisibilityRebuildCount, 1);
    expect(
      SearchFieldClearSuffix.debugListenerFireCount,
      greaterThanOrEqualTo(3),
    );

    controller.clear();
    await tester.pump();
    expect(find.byTooltip('Clear'), findsNothing);
    expect(SearchFieldClearSuffix.debugVisibilityRebuildCount, 2);
  });
}
