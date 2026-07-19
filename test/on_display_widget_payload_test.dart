import 'dart:convert';

import 'package:blindbox_app/features/collection/widget/on_display_widget_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes only the V1 presentation fields', () {
    const payload = OnDisplayWidgetPayload(
      seriesId: 'series-1',
      seriesName: 'Winter Symphony',
      ipName: 'Skullpanda',
      brand: 'POP MART',
      localCoverPath: '/local/cover.png',
      ownedFigureCount: 4,
      regularOwned: 4,
      regularTotal: 12,
      isComplete: false,
      isMasterComplete: false,
    );

    final decoded =
        jsonDecode(OnDisplayWidgetPayload.encodeList([payload]))
            as List<dynamic>;
    final json = decoded.single as Map<String, dynamic>;

    expect(json.keys, {
      'seriesId',
      'seriesName',
      'ipName',
      'brand',
      'localCoverPath',
      'ownedFigureCount',
      'regularOwned',
      'regularTotal',
      'isComplete',
      'isMasterComplete',
    });
    expect(json, isNot(contains('addedAt')));
  });

  test('encodes an empty state as an empty candidate list', () {
    expect(jsonDecode(OnDisplayWidgetPayload.encodeList(const [])), isEmpty);
  });
}
