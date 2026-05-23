import 'package:blindbox_app/features/collection/application/shelf_relationship_analyzer.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/shelf_relationship_insight.dart';
import 'helpers/collection_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared universe insight for co-located IPs', () {
    final snap = CollectionSnapshot(
      shelfSeries: [
        testShelfSeries(id: 's1', taxonomyIpId: 'the_monsters'),
        testShelfSeries(id: 's2', taxonomyIpId: 'the_monsters'),
      ],
      figureStates: const {},
    );

    final insights = analyzeShelfRelationships(snap);
    expect(insights, isNotEmpty);
    expect(insights.first.kind, ShelfRelationshipKind.sharedUniverse);
    expect(insights.length, lessThanOrEqualTo(2));
  });
}
