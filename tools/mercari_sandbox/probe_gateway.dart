// ignore_for_file: avoid_print
import 'dart:io';

import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_gateway_client.dart';

/// Manual gateway probe — not run in CI.
///
/// Usage:
///   dart run tools/mercari_sandbox/probe_gateway.dart --url=https://your-gateway.example
Future<void> main(List<String> args) async {
  String? url;
  for (final arg in args) {
    if (arg.startsWith('--url=')) {
      url = arg.substring('--url='.length);
    }
  }
  if (url == null || url.isEmpty) {
    print('Usage: dart run tools/mercari_sandbox/probe_gateway.dart --url=https://gateway');
    exit(1);
  }

  final uri = Uri.parse(url);
  final client = MercariGatewayClient();
  final response = await client.fetchBrowse(baseUrl: uri);
  print('items=${response.items.length}');
  for (final item in response.items.take(5)) {
    print('- ${item.id}: ${item.title} (${item.priceValue} ${item.currency})');
  }
}
