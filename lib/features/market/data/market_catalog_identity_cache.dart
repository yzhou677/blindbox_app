import 'package:blindbox_app/features/catalog/catalog_seed_loader.dart';
import 'package:blindbox_app/features/market/data/catalog_identity_index.dart';

/// In-memory catalog identity index for marketplace matching.
abstract final class MarketCatalogIdentityCache {
  static CatalogIdentityIndex? _index;

  static CatalogIdentityIndex? get current => _index;

  static bool get hasValue => _index != null;

  static void install(CatalogSeedBundle bundle) {
    _index = CatalogIdentityIndex.fromBundle(bundle);
  }

  static void clear() {
    _index = null;
  }
}
