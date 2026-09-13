import 'package:czechify/core/theme/app_theme.dart';
import 'package:czechify/core/theme/system_bars.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('custom headers update system icons when app theme changes', (
    tester,
  ) async {
    for (final dark in [true, false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? darkTheme() : lightTheme(),
          home: const AppSystemBars(
            child: Scaffold(body: Text('Custom header')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(
        region.value.statusBarIconBrightness,
        dark ? Brightness.light : Brightness.dark,
      );
      expect(
        region.value.systemNavigationBarIconBrightness,
        dark ? Brightness.light : Brightness.dark,
      );
    }
  });
}
