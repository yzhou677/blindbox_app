import 'dart:convert';

import 'package:blindbox_app/features/recommendations/data/preference_signal_extractor.dart';
import 'package:blindbox_app/features/recommendations/data/recommendation_gateway_config.dart';
import 'package:blindbox_app/features/recommendations/data/recommendation_http_client.dart';
import 'package:blindbox_app/features/recommendations/domain/recommendation_reason_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('RecommendationHttpClient parses for-you items with reasonType', () async {
    final client = RecommendationHttpClient(
      client: MockClient((request) async {
        expect(request.url.path, endsWith('/v1/for-you'));
        return http.Response(
          jsonEncode({
            'items': [
              {
                'seriesId': 'dimoo_new',
                'reasonType': RecommendationReasonType.ownedIp,
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
    expect(result.items.first.reasonType, RecommendationReasonType.ownedIp);
    expect(result.items.first.reasonMeta, 'DIMOO');
  });

  test('RecommendationHttpClient posts profile payload', () async {
    final signals = PreferenceSignals(
      ownedCatalogSeriesIds: {'dimoo_owned'},
      wishlistCatalogSeriesIds: const {},
      ownedIpIds: {'dimoo'},
      wishlistIpIds: const {},
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
    expect(decoded['ownedCatalogSeriesIds'], ['dimoo_owned']);
  });
}
