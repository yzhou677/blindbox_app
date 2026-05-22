import 'dart:convert';

import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_browse_response_dto.dart';
import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_gateway_exception.dart';
import 'package:blindbox_app/features/market/data/sandbox/market_sandbox_config.dart';
import 'package:http/http.dart' as http;

/// HTTP client for the Mercari browse gateway (provider wire only).
class MercariGatewayClient {
  MercariGatewayClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// `GET {baseUrl}/v1/browse?limit=N`
  Future<MercariBrowseResponseDto> fetchBrowse({
    required Uri baseUrl,
    int limit = MarketSandboxConfig.maxMercariItems,
  }) async {
    final uri = baseUrl.replace(
      path: '${_normalizedPath(baseUrl.path)}/v1/browse',
      queryParameters: {'limit': '$limit'},
    );

    final response = await _client
        .get(uri)
        .timeout(MarketSandboxConfig.requestTimeout);

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
  }

  static String _normalizedPath(String path) {
    if (path.isEmpty || path == '/') return '';
    return path.endsWith('/') ? path.substring(0, path.length - 1) : path;
  }
}
