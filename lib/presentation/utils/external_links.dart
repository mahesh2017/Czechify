import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a canonical public page outside the app and leaves a usable fallback
/// when Android has no browser registered for HTTPS links.
Future<void> openExternalPage(BuildContext context, String url) async {
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    // The visible fallback below is more useful than a platform exception.
  }

  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open a browser. Visit $url')),
    );
  }
}
