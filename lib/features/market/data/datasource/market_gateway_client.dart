import 'dart:convert';

import 'package:blindbox_app/features/market/data/datasource/gateway_item_detail_dto.dart';
import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_browse_response_dto.dart';
import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_gateway_exception.dart';
import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_gateway_policy.dart';
import 'package:blindbox_app/features/market/data/gateway/market_gateway_config.dart';
import 'package:blindbox_app/features/market/domain/market_browse_query.dart';
import 'package:http/http.dart' as http;

/// HTTP client for the market browse gateway (provider-neutral wire JSON).
class MarketGatewayClient {
  MarketGatewayClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// `GET {baseUrl}/v1/browse` with provider-neutral query facets.
  Future<MercariBrowseResponseDto> fetchBrowse({
    required Uri baseUrl,
    required MarketBrowseQuery query,
  }) {
    return mercariGatewayWithRetries(() async {
      final params = <String, String>{
        'limit': '${query.limit}',
        'brandId': query.brandId,
        'ipId': query.ipId,
        if (query.searchText.trim().isNotEmpty)
          'searchText': query.searchText.trim(),
        'sort': query.sort.wireName,
      };
      final c = query.cursor?.trim();
      if (c != null && c.isNotEmpty) params['cursor'] = c;

      final uri = baseUrl.replace(
        path: '${_normalizedPath(baseUrl.path)}/v1/browse',
        queryParameters: params,
      );

      final response = await _client
          .get(uri)
          .timeout(MarketGatewayConfig.requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MercariGatewayException(
          'Gateway returned ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw MercariGatewayException('Gateway response is not a JSON object');
      }
      return MercariBrowseResponseDto.fromJson(decoded);
    });
  }

  /// `GET {baseUrl}/v1/item?itemId=` for enriched listing facts.
  Future<GatewayItemDetailDto?> fetchItemDetail({
    required Uri baseUrl,
    required String itemId,
  }) {
    return mercariGatewayWithRetries(() async {
      final trimmed = itemId.trim();
      if (trimmed.isEmpty) return null;

      final uri = baseUrl.replace(
        path: '${_normalizedPath(baseUrl.path)}/v1/item',
        queryParameters: {'itemId': trimmed},
      );

      final response = await _client
          .get(uri)
          .timeout(MarketGatewayConfig.requestTimeout);

      if (response.statusCode == 404) return null;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MercariGatewayException(
          'Gateway returned ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw MercariGatewayException('Gateway response is not a JSON object');
      }
      return GatewayItemDetailDto.tryParse(decoded);
    });
  }

  static String _normalizedPath(String path) {
    if (path.isEmpty || path == '/') return '';
    return path.endsWith('/') ? path.substring(0, path.length - 1) : path;
  }
}
