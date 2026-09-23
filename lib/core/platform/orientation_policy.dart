import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Android's large-screen boundary, expressed in logical pixels (dp).
///
/// Phones remain portrait-only. Tablets, unfolded large-screen foldables,
/// ChromeOS devices, and other displays at or above this boundary may rotate.
const double largeScreenShortestSide = 600;

/// Returns the orientation request appropriate for a physical display.
///
/// An empty list clears Flutter's orientation preference and lets the device
/// and user choose any supported orientation.
List<DeviceOrientation> preferredOrientationsForDisplay(Size logicalSize) {
  if (logicalSize.shortestSide >= largeScreenShortestSide) {
    return const <DeviceOrientation>[];
  }
  return const <DeviceOrientation>[DeviceOrientation.portraitUp];
}

/// Applies the Android orientation policy using the display size rather than
/// the current app window size.
///
/// Using the display avoids treating a tablet as a phone when Czechify is in a
/// narrow split-screen window. Metrics are re-evaluated by the app lifecycle
/// observer, which also covers fold/unfold and external-display changes.
Future<void> applyAdaptiveOrientationPolicy() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return;

  final display = views.first.display;
  final logicalSize = display.size / display.devicePixelRatio;
  await SystemChrome.setPreferredOrientations(
    preferredOrientationsForDisplay(logicalSize),
  );
}
