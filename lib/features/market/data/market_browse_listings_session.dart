import 'package:blindbox_app/models/market_listing.dart';

/// In-memory browse catalog installed before [runApp] / tests (sync read via Riverpod).
final class MarketBrowseListingsSession {
  MarketBrowseListingsSession._();

  static final MarketBrowseListingsSession instance = MarketBrowseListingsSession._();

  List<MarketListing>? _list;

  bool get isInstalled => _list != null;

  List<MarketListing> get list {
    final v = _list;
    if (v == null) {
      throw StateError(
        'Market browse listings not installed. Call install() from main() or test bootstrap.',
      );
    }
    return v;
  }

  void install(List<MarketListing> listings) {
    _list = List<MarketListing>.unmodifiable(listings);
  }

  void reset() {
    _list = null;
  }

  MarketListing? findById(String id) {
    for (final m in list) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Fixture rows flagged as chaser candidates (`isTrending` in bundled JSON).
  List<MarketListing> get chasers =>
      list.where((e) => e.isTrending).toList(growable: false);

  @Deprecated('Use chasers')
  List<MarketListing> get trending => chasers;
}
