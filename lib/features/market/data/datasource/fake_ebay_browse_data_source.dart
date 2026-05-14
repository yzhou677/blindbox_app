import 'dart:convert';

import 'package:blindbox_app/features/market/data/datasource/market_browse_data_source.dart';
import 'package:blindbox_app/features/market/data/dto/ebay_item_summary_dto.dart';
import 'package:flutter/services.dart';

/// Loads fake eBay-shaped JSON from app assets (offline-first demo).
class FakeEbayBrowseDataSource implements MarketBrowseDataSource {
  FakeEbayBrowseDataSource({this.assetPath = 'assets/market/fake_ebay_browse_items.json'});

  final String assetPath;

  @override
  Future<List<EbayItemSummaryDto>> fetchBrowseSummaries() async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final items = decoded['items'] as List<dynamic>? ?? const [];
    return items
        .map((e) => EbayItemSummaryDto.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
