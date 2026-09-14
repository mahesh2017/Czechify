import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
