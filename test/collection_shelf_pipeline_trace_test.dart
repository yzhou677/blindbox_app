import 'package:blindbox_app/features/collection/debug/collection_shelf_pipeline_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CollectionShelfPipelineTrace is a no-op outside debug mode', () {
    final trace = CollectionShelfPipelineTrace.start();
    final value = trace.section('Search', () => 42);
    trace.sectionVoid('Filter', () {});
    trace.finish(
      shelfSeries: 48,
      visibleSeries: 48,
      catalogSeries: 343,
      catalogFigures: 2435,
    );
    expect(value, 42);
  });
}
