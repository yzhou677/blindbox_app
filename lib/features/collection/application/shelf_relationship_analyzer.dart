import 'package:blindbox_app/features/collectible_relationship/application/collectible_shelf_relationship_bridge.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/domain/shelf_relationship_insight.dart';

List<ShelfRelationshipInsight> analyzeShelfRelationships(
  CollectionSnapshot snap,
) =>
    analyzeCollectibleShelfRelationships(snap);
