import 'dart:convert';

import 'package:blindbox_app/features/market/data/dto/ebay_item_summary_dto.dart';
import 'package:flutter/services.dart';

/// Loads eBay Browse–shaped browse JSON from a bundled asset.
Future<List<EbayItemSummaryDto>> loadEbayShapedBrowseAsset(String assetPath) async {
  final raw = await rootBundle.loadString(assetPath);
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final items = decoded['items'] as List<dynamic>? ?? const [];
  return items
      .map((e) => EbayItemSummaryDto.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}
