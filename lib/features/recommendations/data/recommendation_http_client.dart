import 'dart:convert';

import 'package:blindbox_app/features/recommendations/data/preference_signal_extractor.dart';
import 'package:blindbox_app/features/recommendations/data/recommendation_gateway_config.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_item.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_result.dart';
import 'package:http/http.dart' as http;

class RecommendationHttpException implements Exception {
  RecommendationHttpException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'RecommendationHttpException($message)';
}

/// HTTP client for recommendation Cloud Functions.
class RecommendationHttpClient {
  RecommendationHttpClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> updateProfile({
    required Uri baseUrl,
    required String installId,
    required PreferenceSignals signals,
  }) async {
    final uri = baseUrl.replace(
      path: '${_normalizedPath(baseUrl.path)}/v1/profile',
    );
    final body = preferenceSignalsToProfileJson(
      installId: installId,
      signals: signals,
    );

    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(RecommendationGatewayConfig.requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RecommendationHttpException(
        'Profile upload returned ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }

  Future<RecommendationResult> fetchForYou({
    required Uri baseUrl,
    required String installId,
  }) async {
    final uri = baseUrl.replace(
      path: '${_normalizedPath(baseUrl.path)}/v1/for-you',
      queryParameters: {'installId': installId},
    );

    final response = await _client
        .get(uri)
        .timeout(RecommendationGatewayConfig.requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RecommendationHttpException(
        'For-you fetch returned ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is! Map<String, dynamic>) {
        throw RecommendationHttpException('For-you response is not a JSON object');
      }
      decoded = parsed;
    } catch (error) {
      if (error is RecommendationHttpException) rethrow;
      throw RecommendationHttpException('For-you response is not valid JSON');
    }

    final rawItems = decoded['items'];
    final items = rawItems is List
        ? [
            for (final entry in rawItems)
              if (entry is Map<String, dynamic>)
                RecommendationItem.tryFromJson(entry),
          ].whereType<RecommendationItem>()
        : const <RecommendationItem>[];

    return RecommendationResult(
      items: items.toList(),
      profileHash: decoded['profileHash'] as String?,
    );
  }

  String _normalizedPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty || trimmed == '/') return '';
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }
}
