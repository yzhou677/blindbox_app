import 'package:blindbox_app/features/catalog/debug/catalog_search_pipeline_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CatalogSearchPipelineTrace.run returns action result unchanged', () {
    final results = CatalogSearchPipelineTrace.run(
      rawQuery: 'hello kitty',
      catalogSeries: 1,
      catalogFigures: 2,
      resultLine: (ids) => 'series=${ids.length}',
      action: () => {'s1'},
    );
    expect(results, {'s1'});
  });

  test('CatalogSearchPipelineTrace is a no-op outside debug mode', () {
    final figures = CatalogSearchPipelineTrace.run(
      rawQuery: '',
      catalogSeries: 0,
      catalogFigures: 0,
      resultLine: (list) => 'figures=${list.length}',
      action: () => <String>['a'],
    );
    expect(figures, ['a']);
  });
}
