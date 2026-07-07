import 'dart:convert';

import 'package:blindbox_app/features/recommendations/data/preference_signal_extractor.dart';
import 'package:blindbox_app/features/recommendations/data/recommendation_gateway_config.dart';
import 'package:blindbox_app/features/recommendations/data/recommendation_http_client.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_reason_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('RecommendationHttpClient parses for-you items with legacy reasonType', () async {
    final client = RecommendationHttpClient(
      client: MockClient((request) async {
        expect(request.url.path, endsWith('/v1/for-you'));
        return http.Response(
          jsonEncode({
            'items': [
              {
                'seriesId': 'dimoo_new',
                'reasonType': RecommendationReasonType.trackedIp,
                'reasonMeta': 'DIMOO',
              },
            ],
          }),
          200,
        );
      }),
    );

    final result = await client.fetchForYou(
      baseUrl: Uri.parse(RecommendationGatewayConfig.gatewayBaseUrl),
      installId: 'install-1',
    );

    expect(result.items, hasLength(1));
    expect(result.items.first.seriesId, 'dimoo_new');
    expect(result.items.first.primaryReasonType, RecommendationReasonType.trackedIp);
    expect(result.items.first.reasonType, RecommendationReasonType.trackedIp);
  });

  test('RecommendationHttpClient parses dual-reason for-you items', () async {
    final client = RecommendationHttpClient(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'seriesId': 'dimoo_new',
                'primaryReasonType': RecommendationReasonType.trackedIp,
                'primaryReasonMeta': 'DIMOO',
                'secondaryReasonType': RecommendationReasonType.recentRelease,
              },
            ],
          }),
          200,
        );
      }),
    );

    final result = await client.fetchForYou(
      baseUrl: Uri.parse(RecommendationGatewayConfig.gatewayBaseUrl),
      installId: 'install-1',
    );
    expect(result.items.first.primaryReasonType, RecommendationReasonType.trackedIp);
    expect(result.items.first.secondaryReasonType, RecommendationReasonType.recentRelease);
    expect(result.items.first.primaryReasonMeta, 'DIMOO');
  });

  test('RecommendationHttpClient posts profile payload', () async {
    final signals = PreferenceSignals(
      trackedCatalogSeriesIds: {'dimoo_owned'},
      ownedCatalogSeriesIds: {'dimoo_owned'},
      wishlistCatalogSeriesIds: const {},
      trackedIpIds: {'dimoo'},
      wishlistIpIds: const {},
      trackedCatalogSeriesCount: 1,
      ownedCatalogSeriesCount: 1,
      wishlistCatalogSeriesCount: 0,
      profileHash: 'hash-123',
    );

    String? capturedBody;
    final client = RecommendationHttpClient(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/v1/profile'));
        capturedBody = request.body;
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );

    await client.updateProfile(
      baseUrl: Uri.parse(RecommendationGatewayConfig.gatewayBaseUrl),
      installId: 'install-1',
      signals: signals,
    );

    final decoded = jsonDecode(capturedBody!) as Map<String, dynamic>;
    expect(decoded['installId'], 'install-1');
    expect(decoded['profileHash'], 'hash-123');
    expect(decoded['trackedCatalogSeriesIds'], ['dimoo_owned']);
    expect(decoded['trackedIpIds'], ['dimoo']);
    expect(decoded.containsKey('wishlistCatalogSeriesIds'), isFalse);
    expect(decoded.containsKey('wishlistIpIds'), isFalse);
  });
}
