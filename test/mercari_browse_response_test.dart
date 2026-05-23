import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_browse_response_dto.dart';
import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_listing_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses nextCursor and skips invalid items', () {
    final dto = MercariBrowseResponseDto.fromJson({
      'items': [
        {'id': 'ok', 'title': 'Good'},
        {'id': '', 'title': 'Bad'},
        {'title': 'No id'},
      ],
      'nextCursor': 'page-2',
      'hasMore': true,
    });
    expect(dto.items.length, 1);
    expect(dto.nextCursor, 'page-2');
    expect(dto.hasMore, isTrue);
  });

  test('MercariListingDto tolerates schema aliases', () {
    final dto = MercariListingDto.tryParse({
      'itemId': 'x1',
      'title': 'Alias id',
      'priceValue': '9',
      'currency': 'USD',
      'imageUrl': 'https://img/a.jpg',
      'itemWebUrl': 'https://listing/a',
    });
    expect(dto?.id, 'x1');
  });
}
