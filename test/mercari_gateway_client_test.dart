import 'dart:convert';

import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_gateway_client.dart';
import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_gateway_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('fetchBrowse parses items envelope', () async {
    final client = MercariGatewayClient(
      client: MockClient((request) async {
        expect(request.url.path, endsWith('/v1/browse'));
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'a1',
                'title': 'Test Figure',
                'price': {'value': '12.50', 'currency': 'USD'},
                'image': {'imageUrl': 'https://img.example/a.jpg'},
                'listingUrl': 'https://market.example/a1',
              },
            ],
          }),
          200,
        );
      }),
    );

    final response = await client.fetchBrowse(
      baseUrl: Uri.parse('https://gateway.example'),
    );
    expect(response.items.length, 1);
    expect(response.items.first.id, 'a1');
  });

  test('non-2xx throws MercariGatewayException', () async {
    final client = MercariGatewayClient(
      client: MockClient((_) async => http.Response('error', 503)),
    );

    expect(
      () => client.fetchBrowse(baseUrl: Uri.parse('https://gateway.example')),
      throwsA(isA<MercariGatewayException>()),
    );
  });
}
