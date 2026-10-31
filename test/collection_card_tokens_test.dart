import 'package:blindbox_app/core/theme/app_card_tokens.dart';
import 'package:blindbox_app/features/collection/presentation/collection_card_tokens.dart';
import 'package:blindbox_app/features/collection/widgets/collection_series_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Collection card tokens share browse width and pack rail extent', () {
    expect(CollectionCardTokens.width, AppCardTokens.browseRailWidth);
    expect(CollectionCardTokens.minRailHeight, 268);
    expect(CollectionCardTokens.compactMinRailHeight, 205);
    expect(CollectionCardTokens.imageToTitleGap, 12);
    expect(CollectionCardTokens.titleToMetaGap, 16);
    expect(CollectionCardTokens.metaToProgressGap, 16);
    expect(CollectionCardTokens.progressToLabelGap, 8);
    expect(CollectionCardTokens.padding.bottom, 16);
    expect(CollectionSeriesCard.railExtent, CollectionCardTokens.minRailHeight);
    expect(
      CollectionCardTokens.minRailHeightFor(
        TextScaler.noScaling,
        metaLineCount: 2,
      ),
      CollectionCardTokens.minRailHeight +
          CollectionCardTokens.metaFirstLineExtent +
          CollectionCardTokens.metaSecondLineExtent,
    );
    expect(
      CollectionCardTokens.minRailHeight,
      greaterThan(AppCardTokens.browseRailHeight),
    );
  });
}
