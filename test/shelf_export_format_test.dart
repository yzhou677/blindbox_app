import 'package:blindbox_app/features/collection/presentation/shelf_export_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats KB / MB / GB labels', () {
    expect(ShelfExportFormat.formatBytes(500), '500 B');
    expect(ShelfExportFormat.formatBytes(2048), '2 KB');
    expect(ShelfExportFormat.formatBytes(5 * 1024 * 1024), '5.0 MB');
    expect(ShelfExportFormat.formatBytes(12 * 1024 * 1024), '12 MB');
    expect(ShelfExportFormat.formatBytes((1.5 * 1024 * 1024 * 1024).round()),
        '1.5 GB');
  });
}
