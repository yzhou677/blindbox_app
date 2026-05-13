import 'package:blindbox_app/models/collectible.dart';

/// A collectible the user owns, with quantity for shelf display.
class OwnedCollectible {
  const OwnedCollectible({
    required this.collectible,
    required this.quantity,
  }) : assert(quantity >= 1);

  final Collectible collectible;
  final int quantity;
}
