import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an official HTTPS link in the system browser.
Future<bool> tryOpenOfficialFeedUrl(String rawUrl) async {
  final url = rawUrl.trim();
  if (url.isEmpty) return false;

  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;

  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> openOfficialFeedUrl(BuildContext context, String url) async {
  final opened = await tryOpenOfficialFeedUrl(url);
  if (!context.mounted) return;
  if (opened) {
    HapticFeedback.selectionClick();
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Could not open link'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
