import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Returns true when the listing URL was handed off to the platform launcher.
Future<bool> tryOpenMarketListingUrl(String? rawUrl) async {
  final url = rawUrl?.trim() ?? '';
  if (url.isEmpty) return false;

  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;

  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Opens the seller listing in the system browser when a URL is available.
Future<void> openMarketListingUrl(BuildContext context, String? url) async {
  final opened = await tryOpenMarketListingUrl(url);
  if (!context.mounted) return;
  if (opened) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Could not open listing')),
  );
}
