import 'package:flutter/material.dart';

/// Stable app-level presentation anchors used by work that may outlive a
/// particular route, such as a Google Play flexible-update download.
final rootNavigatorKey = GlobalKey<NavigatorState>();
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
