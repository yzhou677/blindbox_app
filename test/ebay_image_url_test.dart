import 'package:blindbox_app/features/market/utils/ebay_image_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('upgradeEbayImageUrl upgrades browse thumbs', () {
    expect(
      upgradeEbayImageUrl('https://i.ebayimg.com/g/s-l225.jpg'),
      'https://i.ebayimg.com/g/s-l500.jpg',
    );
  });

  test('upgradeEbayImageUrl upgrades detail thumbs', () {
    expect(
      upgradeEbayImageUrl(
        'https://i.ebayimg.com/g/s-l500.jpg',
        size: EbayImageSize.detail,
      ),
      'https://i.ebayimg.com/g/s-l1600.jpg',
    );
  });

  test('ebayBrowseItemId wraps legacy ids', () {
    expect(ebayBrowseItemId('110589358256'), 'v1|110589358256|0');
    expect(ebayBrowseItemId('v1|110589358256|0'), 'v1|110589358256|0');
  });
}
