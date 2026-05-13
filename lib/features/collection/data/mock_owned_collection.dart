import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:blindbox_app/models/owned_collectible.dart';

/// Local mock shelf (no persistence yet). Clear this list to preview the empty state.
final List<OwnedCollectible> mockOwnedCollection = [
  OwnedCollectible(collectible: mockLatestDrops[0], quantity: 2),
  OwnedCollectible(collectible: mockLatestDrops[1], quantity: 1),
  OwnedCollectible(collectible: mockLatestDrops[2], quantity: 1),
  OwnedCollectible(collectible: mockLatestDrops[3], quantity: 3),
  OwnedCollectible(collectible: mockLatestDrops[4], quantity: 1),
];
