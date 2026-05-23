import 'package:blindbox_app/features/market/domain/collectible_market_snapshot.dart';

/// In-memory collectible market snapshots (derived from browse listings).
final class CollectibleMarketSession {
  CollectibleMarketSession._();

  static final CollectibleMarketSession instance = CollectibleMarketSession._();

  List<CollectibleMarketSnapshot>? _list;
  final Map<String, CollectibleMarketSnapshot> _byListingId = {};

  bool get isInstalled => _list != null;

  List<CollectibleMarketSnapshot> get list {
    final v = _list;
    if (v == null) {
      throw StateError(
        'Collectible market snapshots not installed. Call install() after browse listings.',
      );
    }
    return v;
  }

  void install(List<CollectibleMarketSnapshot> snapshots) {
    _list = List<CollectibleMarketSnapshot>.unmodifiable(snapshots);
    _byListingId.clear();
    for (final snap in snapshots) {
      for (final id in snap.listingIds) {
        _byListingId[id] = snap;
      }
    }
  }

  void reset() {
    _list = null;
    _byListingId.clear();
  }

  CollectibleMarketSnapshot? snapshotForListingId(String listingId) {
    return _byListingId[listingId];
  }
}
