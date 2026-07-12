import 'package:blindbox_app/core/theme/app_card_tokens.dart';
import 'package:blindbox_app/features/collection/presentation/collection_card_tokens.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Collection card tokens share browse width and own rail extent', () {
    expect(CollectionCardTokens.width, AppCardTokens.browseRailWidth);
    expect(CollectionCardTokens.minRailHeight, 276);
    expect(
      CollectionSeriesCard.railExtent,
      CollectionCardTokens.minRailHeight,
    );
    expect(
      CollectionCardTokens.minRailHeight,
      greaterThan(AppCardTokens.browseRailHeight),
    );
  });
}
