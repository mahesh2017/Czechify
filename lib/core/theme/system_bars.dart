import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps Android system UI behavior consistent below and above Android 15.
///
/// Android 15+ enforces edge-to-edge for Czechify's target SDK. Calling this
/// explicitly makes older supported releases behave the same way, while the
/// native activity enables it before Flutter draws its first frame.
Future<void> enableAppEdgeToEdge() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}

/// Custom headers need the same theme-aware system icons as an AppBar.
class AppSystemBars extends StatelessWidget {
  const AppSystemBars({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final style = dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: style.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
      ),
      child: child,
    );
  }
}
