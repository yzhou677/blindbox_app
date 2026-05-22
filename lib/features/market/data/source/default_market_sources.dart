import 'package:blindbox_app/features/market/data/source/asset_market_source.dart';
import 'package:blindbox_app/features/market/data/source/market_source.dart';

/// Phase 1 default: single offline asset feed. Add [MercariMarketSource] / [EbayMarketSource] in Phase 2.
List<MarketSource> defaultMarketSources() => [AssetMarketSource()];
