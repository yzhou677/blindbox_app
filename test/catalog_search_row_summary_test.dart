import 'package:blindbox_app/features/collection/presentation/catalog_search_row_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('single figure match uses Includes', () {
    expect(
      catalogSearchRowSummary(
        figureCount: 12,
        hasChase: false,
        matchedFigureNames: {'Elephant'},
      ),
      'Includes Elephant',
    );
  });

  test('series or multi-figure match uses figure count', () {
    expect(
      catalogSearchRowSummary(
        figureCount: 9,
        hasChase: false,
        matchedFigureNames: {'A', 'B', 'C'},
      ),
      '9 figures',
    );
  });

  test('multi-figure match with chase uses count and suffix', () {
    expect(
      catalogSearchRowSummary(
        figureCount: 12,
        hasChase: true,
        matchedFigureNames: {'A', 'B'},
      ),
      '12 figures • Secret Figure included',
    );
  });

  test('single figure in one-figure series', () {
    expect(
      catalogSearchRowSummary(
        figureCount: 1,
        hasChase: false,
        matchedFigureNames: {'Solo'},
      ),
      'Includes Solo',
    );
  });
}
