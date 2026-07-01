import 'package:blindbox_app/core/debug/app_pipeline_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppPipelineLog.formatMicros', () {
    test('formats sub-millisecond as us', () {
      expect(AppPipelineLog.formatMicros(142), '142us');
    });

    test('formats fractional ms below 10ms', () {
      expect(AppPipelineLog.formatMicros(4200), '4.2ms');
    });

    test('formats whole ms at 10ms and above', () {
      expect(AppPipelineLog.formatMicros(18000), '18ms');
    });
  });

  group('AppPipelinePrefix', () {
    test('collection prefix ends with Pipeline for grep', () {
      expect(AppPipelinePrefix.collection, endsWith('Pipeline'));
      expect(AppPipelinePrefix.catalogSearch, endsWith('Pipeline'));
      expect(AppPipelinePrefix.market, endsWith('Pipeline'));
      expect(AppPipelinePrefix.discover, endsWith('Pipeline'));
      expect(AppPipelinePrefix.feed, endsWith('Pipeline'));
    });
  });
}
