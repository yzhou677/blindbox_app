import 'package:blindbox_app/features/market/data/source/market_source.dart';
import 'package:blindbox_app/models/market_listing.dart';

/// Browse listings: one or more [MarketSource] implementations merged for the session.
class MarketListingsRepository {
  MarketListingsRepository(this._sources);

  final List<MarketSource> _sources;

  Future<List<MarketListing>> loadBrowseListings() async {
    if (_sources.isEmpty) return const [];

    final batches = await Future.wait(
      _sources.map(_loadFromSource),
    );
    final merged = <MarketListing>[];
    for (final batch in batches) {
      merged.addAll(batch);
    }
    return merged;
  }

  Future<List<MarketListing>> _loadFromSource(MarketSource source) async {
    try {
      return await source.fetchBrowseListings();
    } catch (_) {
      return const [];
    }
  }
}
