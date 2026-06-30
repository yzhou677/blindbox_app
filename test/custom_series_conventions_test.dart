import 'package:blindbox_app/features/collection/data/custom_series_conventions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('slugId normalizes display labels to catalog-style ids', () {
    expect(CustomSeriesConventions.slugId('POP MART'), 'pop_mart');
    expect(CustomSeriesConventions.slugId('  Hello!! World  '), 'hello_world');
    expect(CustomSeriesConventions.slugId(''), 'custom');
  });

  test('brandIdFromDisplay defaults to independent', () {
    expect(CustomSeriesConventions.brandIdFromDisplay(null), 'independent');
    expect(CustomSeriesConventions.brandIdFromDisplay('My Studio'), 'my_studio');
  });

  test('figure and series imageKey stems follow instance id pattern', () {
    const sid = 'custom-123';
    expect(CustomSeriesConventions.seriesImageKey(sid), sid);
    expect(CustomSeriesConventions.figureImageKey(sid, 0), 'custom-123-f-0');
  });

  test('rarityLine maps secret + ratio label', () {
    expect(
      CustomSeriesConventions.rarityLine(isSecret: true, rarityLabel: '1:72'),
      '1:72',
    );
    expect(
      CustomSeriesConventions.rarityLine(isSecret: true, rarityLabel: null),
      'Secret Figure',
    );
    expect(
      CustomSeriesConventions.rarityLine(isSecret: false, rarityLabel: null),
      'Regular',
    );
  });
}
