import 'package:blindbox_app/core/theme/app_theme.dart';
import 'package:blindbox_app/features/collection/data/collection_input_limits.dart';
import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:blindbox_app/features/collection/widgets/custom_series_form_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Finder formFieldAt(int index) {
    return find.descendant(
      of: find.byType(CustomSeriesFormSheet),
      matching: find.byType(TextFormField),
    ).at(index);
  }

  String fieldText(WidgetTester tester, int index) {
    return tester
        .widget<TextFormField>(formFieldAt(index))
        .controller!
        .text;
  }

  testWidgets('custom series form enforces maxLength and blocks line breaks', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CollectibleSheetScope(
            scrollController: ScrollController(),
            child: CustomSeriesFormSheet.create(
              onSubmit:
                  ({
                    required String seriesName,
                    String? brand,
                    String? ipDisplayName,
                    required List<CustomFigureDraft> figures,
                    String? customCoverImageUri,
                    String? notes,
                  }) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(formFieldAt(0), 'n' * 120);
    expect(
      fieldText(tester, 0).length,
      CollectionInputLimits.seriesNameMaxLength,
    );

    await tester.enterText(formFieldAt(1), 'b' * 80);
    expect(
      fieldText(tester, 1).length,
      CollectionInputLimits.brandMaxLength,
    );

    await tester.enterText(formFieldAt(2), 'hello\nworld');
    expect(fieldText(tester, 2), 'helloworld');

    await tester.enterText(formFieldAt(3), 'note\nline\n${'z' * 600}');
    final notes = fieldText(tester, 3);
    expect(notes.contains('\n'), isTrue);
    expect(notes.length, CollectionInputLimits.notesMaxLength);
  });
}
