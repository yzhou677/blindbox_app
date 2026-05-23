import 'dart:convert';

import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_gateway_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('retries once on 503 then succeeds', () async {
    var calls = 0;
    final client = MercariGatewayClient(
      client: MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('unavailable', 503);
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'a1', 'title': 'Retry OK'},
            ],
          }),
          200,
        );
      }),
    );

    final response = await client.fetchBrowse(
      baseUrl: Uri.parse('https://gateway.example'),
    );
    expect(calls, 2);
    expect(response.items.length, 1);
  });
}
