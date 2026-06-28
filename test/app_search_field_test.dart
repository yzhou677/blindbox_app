import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/shared/widgets/app_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppSearchField uses M3 prefix constraints and text inset',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppSearchField(hintText: 'Search catalog'),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    final decoration = field.decoration!;

    expect(decoration.prefixIconConstraints?.minWidth, 48);
    expect(decoration.contentPadding, const EdgeInsets.fromLTRB(12, 14, 12, 14));
    expect(decoration.contentPadding?.resolve(TextDirection.ltr).left,
        AppSpacing.md);
  });
}
