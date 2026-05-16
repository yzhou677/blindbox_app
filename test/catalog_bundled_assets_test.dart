import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled catalog figure and series PNGs resolve in asset bundle', () async {
    for (final path in const [
      'assets/catalog/figures/the_monsters_exciting_macaron_soymilk.png',
      'assets/catalog/series/the_monsters_exciting_macaron.png',
    ]) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(200),
          reason: 'Expected non-trivial PNG payload for $path');
    }
  });
}
